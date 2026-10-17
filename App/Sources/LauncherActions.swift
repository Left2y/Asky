import SwiftUI
import Contracts
import Theme

struct LauncherAction {
    enum Kind { case result(ResultAction), copyPath }
    let title: String
    let icon: String
    let shortcut: String?
    let kind: Kind

    init(title: String, icon: String, shortcut: String?, kind: Kind) {
        self.title = title
        self.icon = icon
        self.shortcut = shortcut
        self.kind = kind
    }

    init(action: ResultAction, source: SearchSource, shortcut: String? = nil) {
        let presentation: (String, String) = switch action {
        case .open: (source == .app ? "打开应用" : source == .clipboard ? "复制" : "打开", "arrow.up.right")
        case .revealInFinder: ("在访达中显示", "folder")
        case .switchTo: ("切换标签页", "globe")
        case .copy: ("复制结果", "doc.on.clipboard")
        case .openURL: ("打开链接", "link")
        case .runTerminal: ("运行命令", "terminal")
        case .runShortcut: ("运行快捷指令", "square.stack.3d.up")
        case .askAI: ("询问 AI", "sparkles")
        }
        self.init(title: presentation.0, icon: presentation.1, shortcut: shortcut, kind: .result(action))
    }
}

/// Floats over the scrolling results. The list owns the matching edge dissolve.
struct LauncherActionBar: View {
    @Bindable var model: LauncherModel

    var body: some View {
        HStack {
            if let primary = model.primaryLauncherAction {
                Button { model.performLauncherAction(primary) } label: {
                    actionLabel(primary.title, icon: primary.icon, shortcut: primary.shortcut)
                }
                .buttonStyle(.plain)
                .nativeGlassBackground(in: Capsule(), interactive: true)
            }
            Spacer(minLength: 12)
            if !model.secondaryActions.isEmpty {
                Button { model.toggleActionsMenu() } label: {
                    actionLabel("更多", icon: "ellipsis.circle", shortcut: "⌘ K")
                }
                .buttonStyle(.plain)
                .nativeGlassBackground(in: Capsule(), interactive: true)
                .accessibilityValue(model.isActionsMenuPresented ? "On" : "Off")
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .frame(height: LauncherLayout.actionBarHeight, alignment: .bottom)
    }

    private func actionLabel(_ title: String, icon: String, shortcut: String?) -> some View {
        HStack(spacing: 8) {
            Image(mingCute: icon, size: 14)
            Text(NSLocalizedString(title, tableName: "Launcher", comment: "Launcher action"))
            if let shortcut { LauncherActionKeyCap(value: shortcut) }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(ThemeColor.kText)
        .padding(.horizontal, 12)
        .frame(height: 32)
        .contentShape(Capsule())
    }
}

struct LauncherActionKeyCap: View {
    let value: String
    var body: some View {
        Text(value)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(ThemeColor.kTextSubtle)
            .padding(.horizontal, 5)
            .frame(height: 20)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(ThemeColor.kBorder, lineWidth: 1))
            .accessibilityHidden(true)
    }
}

/// A non-key child surface: keyboard input stays in the search field.
struct LauncherActionsMenu: View {
    @Bindable var model: LauncherModel
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(model.secondaryActions.enumerated()), id: \.offset) { index, action in
                Button { model.performLauncherAction(action) } label: {
                    HStack(spacing: 10) {
                        Image(mingCute: action.icon, size: 16).frame(width: 20)
                        Text(NSLocalizedString(action.title, tableName: "Launcher", comment: "Launcher action"))
                        Spacer(minLength: 8)
                        if let shortcut = action.shortcut { LauncherActionKeyCap(value: shortcut) }
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(model.actionSelection == index ? ThemeColor.kInteractionHover.color(for: colorScheme) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10))
                .onHover { if $0 { model.actionSelection = index } }
                .accessibilityAddTraits(model.actionSelection == index ? .isSelected : [])
            }
        }
        .padding(8)
        .frame(width: LauncherLayout.actionsMenuWidth)
        .foregroundStyle(ThemeColor.kText)
        .windowSurfaceBackground(in: RoundedRectangle(cornerRadius: 18))
    }
}
