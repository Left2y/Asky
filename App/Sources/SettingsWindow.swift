import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general = "advanced", model, hotkey, aliases, keywords
    case sources, permissions, memory, mcp

    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: "通用"
        case .model: "模型设置"
        case .hotkey: "触发快捷键"
        case .aliases: "别名与快捷指令"
        case .keywords: "网页关键词"
        case .sources: "数据来源"
        case .permissions: "系统权限"
        case .memory: "记忆"
        case .mcp: "外部 MCP"
        }
    }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .model: "sparkles"
        case .hotkey: "keyboard"
        case .aliases: "command"
        case .keywords: "globe"
        case .sources: "square.stack.3d.up"
        case .permissions: "hand.raised.fill"
        case .memory: "brain"
        case .mcp: "point.3.connected.trianglepath.dotted"
        }
    }
    var color: Color {
        switch self {
        case .general, .hotkey: .gray
        case .model, .memory: .purple
        case .aliases: .orange
        case .keywords, .sources: .blue
        case .permissions: .green
        case .mcp: .teal
        }
    }
    static func resolve(_ id: String) -> Self { Self(rawValue: id) ?? .general }
}

/// The app and regression harness share the same AppKit window and sidebar chrome.
@MainActor
enum SettingsWindow {
    static let initialSize = NSSize(width: 960, height: 680)
    static let minimumSize = NSSize(width: 820, height: 560)

    static func make(app: AppModel) -> NSWindow {
        let controller = SettingsSplitViewController(app: app)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: initialSize),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.contentViewController = controller
        window.contentMinSize = minimumSize
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        let toolbar = NSToolbar(identifier: "AskySettings")
        toolbar.delegate = controller
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.setContentSize(initialSize)
        controller.updateChrome()
        return window
    }
}

@MainActor
private final class SettingsSplitViewController: NSSplitViewController, NSToolbarDelegate {
    private let app: AppModel
    private let heading = NSTextField(labelWithString: "")
    private static let separator = NSToolbarItem.Identifier("settingsSeparator")
    private static let title = NSToolbarItem.Identifier("settingsTitle")

    init(app: AppModel) {
        self.app = app
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        let sidebar = NSHostingController(rootView: SettingsSidebar(app: app) { [weak self] in
            self?.updateChrome()
        })
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarItem.minimumThickness = 220
        sidebarItem.maximumThickness = 280
        sidebarItem.canCollapse = false
        sidebarItem.canCollapseFromWindowResize = false
        sidebarItem.holdingPriority = .defaultHigh
        sidebarItem.allowsFullHeightLayout = true
        addSplitViewItem(sidebarItem)

        let detail = NSHostingController(rootView: SettingsView(app: app))
        let detailItem = NSSplitViewItem(viewController: detail)
        detailItem.minimumThickness = 540
        detailItem.automaticallyAdjustsSafeAreaInsets = true
        addSplitViewItem(detailItem)
        heading.font = .systemFont(ofSize: 20, weight: .semibold)
        heading.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    func updateChrome() {
        heading.stringValue = SettingsPage.resolve(app.settingsTab).title
        heading.sizeToFit()
        view.window?.title = "\(heading.stringValue) — Asky 设置"
        switch app.preferences.appearance {
        case "light": view.window?.appearance = NSAppearance(named: .aqua)
        case "dark": view.window?.appearance = NSAppearance(named: .darkAqua)
        default: view.window?.appearance = nil
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, Self.separator, Self.title, .flexibleSpace]
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if id == Self.separator {
            return NSTrackingSeparatorToolbarItem(identifier: id, splitView: splitView, dividerIndex: 0)
        }
        if id == Self.title {
            let item = NSToolbarItem(itemIdentifier: id)
            item.view = heading
            item.label = "设置页面"
            return item
        }
        return nil
    }
}

private struct SettingsSidebar: View {
    @Bindable var app: AppModel
    let updateChrome: () -> Void

    var body: some View {
        List(selection: Binding<String?>(
            get: { SettingsPage.resolve(app.settingsTab).rawValue },
            set: { if let id = $0 { app.settingsTab = id } }
        )) {
            ForEach(SettingsPage.allCases) { page in
                Label {
                    Text(page.title)
                } icon: {
                    Image(systemName: page.symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(page.color, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .padding(.vertical, 3)
                .tag(page.rawValue)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .onChange(of: app.settingsTab) { _, _ in updateChrome() }
        .onChange(of: app.preferences.appearance) { _, _ in updateChrome() }
    }
}
