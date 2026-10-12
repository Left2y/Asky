import AppKit

/// Shared presentation for app-owned alerts. System permission and file panels remain system-owned.
@MainActor
public enum AppDialog {
    public static func make() -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .informational
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            alert.icon = icon
        }
        return alert
    }

    public static func addDetails(to alert: NSAlert, text: String) {
        alert.accessoryView = DialogDetails(text: text) { [weak alert] in
            alert?.layout()
        }
    }
}

@MainActor
private final class DialogDetails: NSStackView {
    private let disclosure = NSButton()
    private let scroll = NSScrollView()
    private let relayout: () -> Void

    init(text: String, relayout: @escaping () -> Void) {
        self.relayout = relayout
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        orientation = .vertical
        alignment = .leading
        spacing = 8
        disclosure.title = "▸ " + NSLocalizedString("操作详情", comment: "")
        disclosure.setButtonType(.onOff)
        disclosure.bezelStyle = .inline
        disclosure.isBordered = false
        disclosure.alignment = .left
        disclosure.font = .systemFont(ofSize: 12)
        disclosure.setAccessibilityLabel(NSLocalizedString("操作详情", comment: ""))
        disclosure.translatesAutoresizingMaskIntoConstraints = false
        disclosure.widthAnchor.constraint(equalToConstant: 260).isActive = true
        disclosure.target = self
        disclosure.action = #selector(toggleDetails)
        addArrangedSubview(disclosure)
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.borderType = .bezelBorder
        let content = NSTextView(frame: NSRect(x: 0, y: 0, width: 260, height: 160))
        content.isEditable = false
        content.isSelectable = true
        content.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        content.string = text
        content.isVerticallyResizable = true
        content.isHorizontallyResizable = false
        content.textContainer?.widthTracksTextView = true
        content.textContainerInset = NSSize(width: 6, height: 6)
        scroll.documentView = content
        scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.widthAnchor.constraint(equalToConstant: 260),
            scroll.heightAnchor.constraint(equalToConstant: 160)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func toggleDetails() {
        disclosure.title = (disclosure.state == .on ? "▾ " : "▸ ") + NSLocalizedString("操作详情", comment: "")
        if disclosure.state == .on { addArrangedSubview(scroll) }
        else { removeArrangedSubview(scroll); scroll.removeFromSuperview() }
        frame.size.height = disclosure.state == .on ? 192 : 24
        relayout()
    }
}
