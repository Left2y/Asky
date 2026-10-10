import Carbon.HIToolbox
import AppKit

/// Global hotkey via Carbon `RegisterEventHotKey` (no Accessibility permission needed).
/// Registration fails with `eventHotKeyExistsErr` when another app already owns the combination.
@MainActor
final class HotKey {
    enum Failure: Error { case alreadyInUse, failed(OSStatus) }

    private var ref: EventHotKeyRef?
    private static var handler: EventHandlerRef?
    private let action: () -> Void
    private static var instances: [UInt32: HotKey] = [:]
    private static var nextID: UInt32 = 1

    init(keyCode: UInt32 = UInt32(kVK_Space), modifiers: UInt32 = UInt32(optionKey), action: @escaping () -> Void) throws {
        self.action = action
        let id = Self.nextID
        Self.nextID += 1
        if Self.handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
                var hk = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &hk)
                let id = hk.id
                MainActor.assumeIsolated { HotKey.instances[id]?.action() }
                return noErr
            }, 1, &spec, nil, &Self.handler)
            guard status == noErr else { throw Failure.failed(status) }
        }
        let reg = RegisterEventHotKey(keyCode, modifiers, EventHotKeyID(signature: OSType(0x4B554C41), id: id),
                                      GetApplicationEventTarget(), 0, &ref)
        guard reg == noErr else {
            if Self.instances.isEmpty, let handler = Self.handler {
                RemoveEventHandler(handler)
                Self.handler = nil
            }
            throw reg == OSStatus(eventHotKeyExistsErr) ? Failure.alreadyInUse : Failure.failed(reg)
        }
        Self.instances[id] = self
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        Self.instances = Self.instances.filter { $0.value !== self }
        if Self.instances.isEmpty, let handler = Self.handler {
            RemoveEventHandler(handler)
            Self.handler = nil
        }
    }
}
