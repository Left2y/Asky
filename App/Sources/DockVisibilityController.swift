import AppKit

/// Dock visibility follows the user's preference independently of open windows.
@MainActor
final class DockVisibilityController {
    var showDockIcon = false { didSet { update() } }

    private func update() {
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }
}
