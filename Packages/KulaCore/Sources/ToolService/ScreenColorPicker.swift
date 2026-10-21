import AppKit

extension ToolService {
    @MainActor private static var isSamplingScreenColor = false

    /// Uses the system sampling UI; cancellation leaves the pasteboard untouched.
    @MainActor
    public static func pickScreenColor(completion: @escaping @MainActor (Bool?) -> Void) {
        guard !isSamplingScreenColor else { return }
        isSamplingScreenColor = true
        NSColorSampler().show { color in
            // AppKit guarantees that the selection handler runs on the main thread.
            MainActor.assumeIsolated {
                isSamplingScreenColor = false
                guard let color else { completion(nil); return }
                completion(copyScreenColor(color))
            }
        }
    }

    /// Convert the sampled color profile to sRGB before rounding to CSS hex bytes.
    @MainActor
    public static func screenColorHex(_ color: NSColor) -> String? {
        guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
        let components = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
        guard components.allSatisfy({ $0.isFinite }) else { return nil }
        let bytes = components.map { Int((min(1, max(0, $0)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", bytes[0], bytes[1], bytes[2])
    }

    @MainActor
    @discardableResult
    public static func copyScreenColor(_ color: NSColor, to pasteboard: NSPasteboard = .general) -> Bool {
        guard let hex = screenColorHex(color) else { return false }
        pasteboard.clearContents()
        return pasteboard.setString(hex, forType: .string)
    }
}
