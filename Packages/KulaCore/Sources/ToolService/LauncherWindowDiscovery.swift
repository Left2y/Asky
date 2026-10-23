import AppKit
import ApplicationServices
import Darwin
import Carbon

/// Cold-start recovery for windows omitted by AXWindows on inactive Spaces.
/// WindowServer supplies exact IDs. Window actions require a matching AXWindow root.
enum LauncherWindowDiscovery {
    typealias ElementFromToken = @convention(c) (CFData) -> Unmanaged<AXUIElement>?
    typealias WindowIDForElement = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    nonisolated(unsafe) private static let library = dlopen(
        "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY)
    struct Runtime: Sendable {
        let createElement: ElementFromToken?
        let getWindow: WindowIDForElement?
        static let system = Runtime(
            createElement: symbol("_AXUIElementCreateWithRemoteToken", as: ElementFromToken.self),
            getWindow: symbol("_AXUIElementGetWindow", as: WindowIDForElement.self))
    }

    private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let library, let address = dlsym(library, name) else { return nil }
        return unsafeBitCast(address, to: type)
    }

    static func windowID(_ element: AXUIElement, runtime: Runtime = .system) -> CGWindowID? {
        guard let windowIDForElement = runtime.getWindow else { return nil }
        var id: CGWindowID = 0
        return windowIDForElement(element, &id) == .success && id != 0 ? id : nil
    }

    struct Record: Sendable {
        let pid: pid_t
        let id: CGWindowID
        let title: String
        let fullScreen: Bool
    }
    private typealias MainConnection = @convention(c) () -> UInt32
    private typealias ManagedSpaces = @convention(c) (UInt32) -> Unmanaged<CFArray>?
    private typealias WindowSpaces = @convention(c) (UInt32, Int, CFArray) -> Unmanaged<CFArray>?
    private typealias ProcessForPID = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> Int32
    private static let processForPID = symbol("GetProcessForPID", as: ProcessForPID.self)
    private typealias FrontWindow = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> CGError
    nonisolated(unsafe) private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    private static func skySymbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let skyLight, let address = dlsym(skyLight, name) else { return nil }
        return unsafeBitCast(address, to: type)
    }
    private static let connection = skySymbol("CGSMainConnectionID", as: MainConnection.self)
    private static let managedSpaces = skySymbol("CGSCopyManagedDisplaySpaces", as: ManagedSpaces.self)
    private static let windowSpaces = skySymbol("CGSCopySpacesForWindows", as: WindowSpaces.self)
    private typealias KeyWindowEvent = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> CGError
    private static let keyWindowEvent = skySymbol("SLPSPostEventRecordTo", as: KeyWindowEvent.self)
    private static let frontWindow = skySymbol("_SLPSSetFrontProcessWithOptions", as: FrontWindow.self)

    static var canResolvePhysicalWindows: Bool { frontWindow != nil && keyWindowEvent != nil && processForPID != nil && windowIDForElementAvailable }
    private static var windowIDForElementAvailable: Bool { Runtime.system.getWindow != nil }

    /// Reads metadata only; title falls back to the app name when WindowServer redacts it.
    static func records() -> [pid_t: [Record]] {
        guard let records = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] else { return [:] }
        let cid = connection?()
        let displays = cid.flatMap { managedSpaces?($0)?.takeRetainedValue() } as? [[String: Any]] ?? []
        let fullScreenSpaces = Set(displays.flatMap { $0["Spaces"] as? [[String: Any]] ?? [] }.compactMap { space -> UInt64? in
            guard space["type"] as? Int == 4 else { return nil }
            return space["id64"] as? UInt64 ?? space["ManagedSpaceID"] as? UInt64
        })
        var result: [pid_t: [Record]] = [:]
        for record in records {
            guard let pid = record[kCGWindowOwnerPID as String] as? Int32,
                  let id = record[kCGWindowNumber as String] as? UInt32,
                  record[kCGWindowLayer as String] as? Int == 0,
                  (record[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let bounds = record[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  frame.width >= 80, frame.height >= 60 else { continue }
            let spaces = cid.flatMap { windowSpaces?($0, 7, [id] as CFArray)?.takeRetainedValue() } as? [UInt64] ?? []
            let fullScreen = Set(spaces).count == 1 && !fullScreenSpaces.isDisjoint(with: spaces)
            result[pid, default: []].append(Record(pid: pid, id: id,
                title: record[kCGWindowName as String] as? String ?? "", fullScreen: fullScreen))
        }
        return result
    }

    static func fullScreenState(_ record: Record) -> Bool? {
        guard let cid = connection?(), let displays = managedSpaces?(cid)?.takeRetainedValue() as? [[String: Any]],
              let spaces = windowSpaces?(cid, 7, [record.id] as CFArray)?.takeRetainedValue() as? [UInt64] else { return nil }
        let fullScreenSpaces = Set(displays.flatMap { $0["Spaces"] as? [[String: Any]] ?? [] }.compactMap { space -> UInt64? in
            guard space["type"] as? Int == 4 else { return nil }
            return space["id64"] as? UInt64 ?? space["ManagedSpaceID"] as? UInt64
        })
        return Set(spaces).count == 1 && !fullScreenSpaces.isDisjoint(with: spaces)
    }

    static func isPresent(_ record: Record) -> Bool {
        guard let descriptions = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] else { return false }
        return descriptions.contains {
            $0[kCGWindowNumber as String] as? UInt32 == record.id && $0[kCGWindowOwnerPID as String] as? Int32 == record.pid
        }
    }

    /// Called only after user selection. The key-focus event has no mouse-up and targets a point
    /// far outside the content, so it cannot complete a click on a control.
    @MainActor static func reveal(_ record: Record) throws {
        guard isPresent(record), let frontWindow, let keyWindowEvent, let processForPID else { throw WindowSearchError.unavailable }
        var process = ProcessSerialNumber()
        guard processForPID(record.pid, &process) == 0,
              frontWindow(&process, record.id, 0x200) == .success else { throw WindowSearchError.unavailable }
        // WindowServer's 0xf8-byte key-window record lives in a zeroed 0x100-byte buffer.
        // Match by CGWindowID, never coordinates; do not post a mouse-up.
        var event = [UInt8](repeating: 0, count: 0x100)
        event[4] = 0xf8
        event[8] = 1
        event[0x3a] = 0x10
        var id = record.id
        var point = CGPoint(x: 300_000, y: 300_000)
        withUnsafeBytes(of: &id) { event.replaceSubrange(0x3c..<0x40, with: $0) }
        withUnsafeBytes(of: &point) { event.replaceSubrange(0x20..<0x30, with: $0) }
        let result = event.withUnsafeMutableBufferPointer { keyWindowEvent(&process, $0.baseAddress!) }
        guard result == .success else { throw WindowSearchError.unavailable }
    }

    /// Optional runtime-bound AX compatibility entry points, isolated from the public path.
    /// A cursor resumes a bounded sweep instead of repeatedly scanning the same prefix.
    static func recover(pid: pid_t, missing: Set<CGWindowID>, cursor: inout UInt64,
                        deadline: ContinuousClock.Instant, runtime: Runtime = .system) throws -> [AXUIElement] {
        guard !missing.isEmpty, let elementFromToken = runtime.createElement, runtime.getWindow != nil else { return [] }
        let stop = min(deadline, ContinuousClock.now.advanced(by: .milliseconds(150)))
        var remaining = missing
        var found: [AXUIElement] = []
        var token = Data(count: 20)
        var owner = pid
        var kind: UInt32 = 0x636f636f
        withUnsafeBytes(of: &owner) { token.replaceSubrange(0..<4, with: $0) }
        withUnsafeBytes(of: &kind) { token.replaceSubrange(8..<12, with: $0) }
        while ContinuousClock.now < stop {
            try Task.checkCancellation()
            var candidateID = cursor
            cursor &+= 1
            withUnsafeBytes(of: &candidateID) { token.replaceSubrange(12..<20, with: $0) }
            guard let candidate = elementFromToken(token as CFData)?.takeRetainedValue() else { continue }
            AXUIElementSetMessagingTimeout(candidate, 0.02)
            var role: CFTypeRef?
            let response = AXUIElementCopyAttributeValue(candidate, kAXRoleAttribute as CFString, &role)
            if response == .cannotComplete { break }
            guard response == .success, role as? String == kAXWindowRole,
                  let id = windowID(candidate, runtime: runtime), remaining.contains(id) else { continue }
            var actualOwner: pid_t = 0
            guard AXUIElementGetPid(candidate, &actualOwner) == .success, actualOwner == pid else { continue }
            found.append(candidate)
            remaining.remove(id)
            if remaining.isEmpty { cursor = 0; break }
        }
        return found
    }
}
