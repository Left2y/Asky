import AppKit

/// Settings temporarily need a regular app; the user's preference keeps it regular after closing.
@MainActor
final class DockVisibilityController {
    var showDockIcon = false { didSet { update() } }
    var settingsOpen = false { didSet { update() } }

    private func update() {
        NSApp.setActivationPolicy(showDockIcon || settingsOpen ? .regular : .accessory)
    }
}
