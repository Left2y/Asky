import AppKit
import Carbon.HIToolbox

@main @MainActor
enum HotKeyRegression {
    static func main() throws {
        _ = NSApplication.shared
        let modifiers = UInt32(controlKey | optionKey | cmdKey | shiftKey)
        let first = try HotKey(keyCode: UInt32(kVK_F16), modifiers: modifiers) {}
        let second = try HotKey(keyCode: UInt32(kVK_F17), modifiers: modifiers) {}
        first.unregister()
        let replacement = try HotKey(keyCode: UInt32(kVK_F16), modifiers: modifiers) {}
        second.unregister()
        replacement.unregister()
        let fresh = try HotKey(keyCode: UInt32(kVK_F16), modifiers: modifiers) {}
        fresh.unregister()
        print("Multiple hotkeys, replacement and handler reinstall passed")
    }
}
