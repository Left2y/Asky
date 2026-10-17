import AppKit
import SwiftUI
import Contracts
import Theme

/// Presentation is derived from the same actions used by Return and shortcuts.
struct LauncherBarAction {
    let title: String
    let symbol: String
    let shortcut: String
    let perform: () -> Void
}

extension LauncherModel {
    var selectedActionResult: SearchResult? {
        guard terminal == nil, results.indices.contains(selection) else { return nil }
        if currencyConversion != nil {
            return results.first { $0.source == .currency && $0.primaryAction != nil }
        }
        return results[selection]
    }

    func barAction(_ action: ResultAction, for result: SearchResult, primary: Bool) -> LauncherBarAction {
        let title: String
        let symbol: String
        switch action {
        case .open: title = result.target.kind == "bookmark-search" ? "搜索书签" : result.source == .clipboard ? "拷贝" : "打开"; symbol = "arrow.up.forward"
        case .revealInFinder: title = "在访达中显示"; symbol = "folder"
        case .switchTo: title = "切换到标签页"; symbol = "arrow.up.forward.square"
        case .copy:
            if case .openURL = result.primaryAction { title = "拷贝链接"; symbol = "link" }
            else { title = "拷贝结果"; symbol = "doc.on.doc" }
        case .openURL: title = result.source == .keyword ? "搜索" : "打开链接"; symbol = "globe"
        case .runTerminal: title = "在终端中运行"; symbol = "terminal"
        case .runShortcut: title = "运行快捷指令"; symbol = "play"
        case .askAI: title = "询问 AI"; symbol = "sparkles"
        }
        return LauncherBarAction(title: NSLocalizedString(title, tableName: "Launcher", comment: "Result action"),
                                 symbol: symbol,
                                 shortcut: primary ? "↩" : action == .revealInFinder ? actionPreferences.revealInFinderHotKey.label : "",
                                 perform: { [weak self] in self?.execute(result, action: action) })
    }

    var commonBarActions: [LauncherBarAction] {
        guard let result = selectedActionResult, let primary = result.primaryAction else { return [] }
        var actions = [barAction(primary, for: result, primary: true)]
        if primary != .revealInFinder, result.actions.contains(.revealInFinder) {
            actions.append(barAction(.revealInFinder, for: result, primary: false))
        }
        return actions
    }

    var extraBarActions: [LauncherBarAction] {
        guard let result = selectedActionResult, let primary = result.primaryAction else { return [] }
        var actions = result.actions.filter { $0 != primary && $0 != .revealInFinder }
            .map { barAction($0, for: result, primary: false) }
        if result.actions.contains(.revealInFinder) {
            actions.append(LauncherBarAction(title: NSLocalizedString("拷贝路径", tableName: "Launcher", comment: ""),
                                             symbol: "doc.on.doc", shortcut: actionPreferences.copyPathHotKey.label,
                                             perform: { [weak self] in _ = self?.copyPath(of: result) }))
        }
        if case .openURL(let url) = primary, !result.actions.contains(.copy(url.absoluteString)) {
            actions.append(LauncherBarAction(title: NSLocalizedString("拷贝链接", tableName: "Launcher", comment: ""),
                                             symbol: "link", shortcut: "",
                                             perform: { [weak self] in self?.execute(result, action: .copy(url.absoluteString)) }))
        }
        return actions
    }
}

struct LauncherActionBar: View {
    let model: LauncherModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(model.commonBarActions.enumerated()), id: \.offset) { index, action in
                if index > 0 {
                    Rectangle().fill(ThemeColor.kBorder).frame(width: 1, height: 16)
                }
                Button(action: action.perform) {
                    HStack(spacing: 8) {
                        Text(action.title)
                        Text(action.shortcut).foregroundStyle(ThemeColor.kTextSubtle)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: LauncherLayout.actionBarHeight)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 12))
        .fixedSize()
        .foregroundStyle(ThemeColor.kText.color(for: colorScheme))
        .nativeGlassBackground(in: Capsule())
        .accessibilityIdentifier("launcher-action-bar")
    }
}

/// AppKit's menu retains native keyboard navigation, dismissal and screen-edge placement.
struct LauncherActionsMenu: NSViewRepresentable {
    let actions: [LauncherBarAction]
    let launcher: LauncherPanel

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "", target: context.coordinator, action: #selector(Coordinator.open(_:)))
        button.bezelStyle = .accessoryBarAction
        button.isBordered = false
        button.font = .systemFont(ofSize: 12)
        button.identifier = NSUserInterfaceItemIdentifier("launcher-actions-menu")
        button.setAccessibilityLabel(NSLocalizedString("更多操作", tableName: "Launcher", comment: ""))
        updateNSView(button, context: context)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.actions = actions
        context.coordinator.launcher = launcher
        button.title = ""
        button.toolTip = NSLocalizedString("更多操作", tableName: "Launcher", comment: "") + "  ⌘K"
        button.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: nil)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .secondaryLabelColor
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor final class Coordinator: NSObject {
        weak var launcher: LauncherPanel?
        var actions: [LauncherBarAction] = []
        private(set) var activeMenu: NSMenu?
        private var trackingActions: [LauncherBarAction] = []
        @objc func open(_ sender: NSButton) {
            guard let panel = launcher else { return }
            let menu = NSMenu()
            activeMenu = menu
            // Keep the action snapshot alive throughout native menu tracking.
            let snapshot = actions
            trackingActions = snapshot
            for (index, action) in snapshot.enumerated() {
                let item = NSMenuItem(title: action.title + (action.shortcut.isEmpty ? "" : "    " + action.shortcut),
                                      action: #selector(select(_:)), keyEquivalent: "")
                item.tag = index
                item.target = self
                item.image = NSImage(systemSymbolName: action.symbol, accessibilityDescription: nil)
                menu.addItem(item)
            }
            panel.isTrackingActionMenu = true
            defer { panel.isTrackingActionMenu = false; activeMenu = nil }
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.maxY + 6), in: sender)
        }
        @objc func select(_ sender: NSMenuItem) {
            guard trackingActions.indices.contains(sender.tag) else { return }
            trackingActions[sender.tag].perform()
        }
    }
}
