import AppKit
import SwiftUI
import Contracts
import DirectActions
import Theme
import Router
import ToolService

enum LauncherLayout {
    // Keep empty and populated fields aligned to the populated search layout.
    static let topInsetFraction: CGFloat = 0.18
    static let bottomClearance: CGFloat = 24
    static let inputHeight: CGFloat = 52
    static let toolbarWidth = WindowMetrics.launcherWidth
    static let inputLeadingPadding: CGFloat = 28
    static let inputTrailingPadding: CGFloat = 22
    static let inputSpacing: CGFloat = 12
    static let folderScopeMaxWidth: CGFloat = 180
    static let folderScopeHeight: CGFloat = 24
    static let inputAccessoryWidth: CGFloat = 19
    static let inputAccessoryHeight: CGFloat = 24
    static let searchIconSize: CGFloat = 17
    static let shellCornerRadius = inputHeight / 2
    static let dividerHeight: CGFloat = 1
    // Compact, single-line results based on the supplied Tinycast reference.
    static let currencyCardHeight: CGFloat = 146
    static let rowHeight: CGFloat = 38
    static let rowIconSize: CGFloat = 24
    static let maxVisibleResults = 10
    static let sectionHeaderHeight: CGFloat = 30
    static let rowSpacing: CGFloat = 0
    static let listHorizontalPadding: CGFloat = 13
    static let actionBarHeight: CGFloat = 56
    static let actionsMenuWidth: CGFloat = 280
    static let listBottomPadding: CGFloat = 12
    static let rowHorizontalPadding: CGFloat = 16
    static let rowCornerRadius = CGFloat(Radius.values["radius16"] ?? 16)
}

/// Floating, non-activating launcher panel that still takes key focus for the input field.
final class LauncherPanel: NSPanel {
    var onEscape: () -> Void = {}
    var onBlur: () -> Void = {}
    var onKeyChange: (Bool) -> Void = { _ in }
    var onOpenSettings: () -> Void = {}
    var onActionKey: (NSEvent) -> Bool = { _ in false }
    var actionMenuContainsPoint: (NSPoint) -> Bool = { _ in false }
    var onCopyPath: () -> Bool = { false }
    var onRevealInFinder: () -> Bool = { false }
    var actionPreferences: () -> SettingsPreferences = { SettingsPreferences() }

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: LauncherLayout.toolbarWidth,
                                      height: LauncherLayout.inputHeight),
                   styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        // The frame is exactly the glass shell, so the system shadow follows it.
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
    }

    override func sendEvent(_ event: NSEvent) {
        if onActionKey(event) { return }
        if SettingsShortcut.matches(event) { onOpenSettings(); return }
        // Intercept before SwiftUI/field editor routing so ⌥⌘C never degrades to ⌘C.
        if actionPreferences().copyPathHotKey.matches(event),
           (firstResponder as? NSTextView)?.hasMarkedText() != true,
           onCopyPath() { return }
        if actionPreferences().revealInFinderHotKey.matches(event),
           (firstResponder as? NSTextView)?.hasMarkedText() != true,
           onRevealInFinder() { return }
        if event.type == .scrollWheel, !actionMenuContainsPoint(event.locationInWindow),
           routeScrollWheel(event, at: event.locationInWindow) { return }
        super.sendEvent(event)
    }

    /// Route before the field editor or a SwiftUI row can consume the gesture.
    /// Forward the original event to retain precise deltas, phases and momentum.
    @discardableResult
    func routeScrollWheel(_ event: NSEvent, at point: NSPoint) -> Bool {
        guard event.type == .scrollWheel, let contentView,
              let scroll = Self.scrollView(in: contentView) else { return false }
        var interactionRect = scroll.convert(scroll.bounds, to: nil)
        // The input and divider share the result list's scroll interaction.
        interactionRect.size.height += LauncherLayout.inputHeight + LauncherLayout.dividerHeight
        guard interactionRect.contains(point) else { return false }
        scroll.scrollWheel(with: event)
        return true
    }

    private static func scrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.lazy.compactMap { scrollView(in: $0) }.first
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onEscape() }
    override func becomeKey() {
        super.becomeKey()
        onKeyChange(true)
    }
    override func resignKey() {
        super.resignKey()
        onKeyChange(false)
        onBlur()
    }
}

/// Transient surfaces outside the single launcher shell.
struct LauncherChrome: Equatable {
    var toast: String?
}

@MainActor
final class LauncherController {
    private let panel = LauncherPanel()
    private let toastPanel = SurfacePanel()
    private let resultReveal = SurfaceSpring()
    private let outsideClickDismissal = OutsideClickDismissal()
    private let model: LauncherModel
    private var hosting: NSHostingView<AnyView>?
    private var contentID = UUID()
    private var resizeTask: Task<Void, Never>?
    private var hiding = false
    private var chrome = LauncherChrome()
    private var availableShellHeight = CGFloat(WindowMetrics.launcherMaxHeight)
    private var shellHeight = LauncherLayout.inputHeight
    private var targetShellHeight = LauncherLayout.inputHeight
    /// The full-width toolbar's top-left corner; every surface is placed from it.
    private var origin = NSPoint.zero

    init(model: LauncherModel) {
        self.model = model
        panel.onEscape = { [weak self] in
            guard let self else { return }
            if self.model.isActionsMenuPresented { self.model.closeActionsMenu() }
            else if self.model.hasScope { self.model.leaveCommand() }
            else { self.hide() }
        }
        panel.onBlur = { [weak self] in
            guard let self else { return }
            self.model.closeActionsMenu()
            guard !self.model.isConfirmingQuit else { return }
            self.hide()
        }
        panel.onActionKey = { [weak model] event in
            guard let model else { return false }
            return model.handleActionKey(event)
        }
        panel.actionMenuContainsPoint = { [weak model] point in
            guard let model, model.isActionsMenuPresented else { return false }
            return model.actionsMenuFrame.contains(point)
        }
        panel.actionPreferences = { [weak model] in model?.actionPreferences ?? SettingsPreferences() }
        panel.onCopyPath = { [weak model] in model?.copySelectedPath() ?? false }
        panel.onRevealInFinder = { [weak model] in model?.revealSelectionInFinder() ?? false }
        model.onHide = { [weak self] in self?.hide() }
        resultReveal.onStep = { [weak self] height in
            guard let self else { return }
            self.shellHeight = CGFloat(height)
            self.layoutSurfaces()
        }
        toastPanel.ignoresMouseEvents = true
    }

    var onOpenSettings: () -> Void {
        get { panel.onOpenSettings }
        set { panel.onOpenSettings = newValue }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        // Menu/Dock reopen requests can arrive while the launcher is visible.
        // Resetting the spring then would leave the unchanged chrome at alpha 0.
        guard !panel.isVisible else {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        model.rebuildProviders()
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let f = screen?.visibleFrame {
            availableShellHeight = min(CGFloat(WindowMetrics.launcherMaxHeight), floor(f.height * (1 - LauncherLayout.topInsetFraction) - LauncherLayout.bottomClearance))
            // Anchor near the top of the pointer screen, leaving room for results below.
            // NSWindow rounds origins and sizes independently to whole points.
            // A fractional top anchor plus a fractional spring height can round
            // their sum to alternating top edges (a visible one-point jump).
            origin = NSPoint(x: (f.midX - LauncherLayout.toolbarWidth / 2).rounded(),
                             y: (f.maxY - f.height * LauncherLayout.topInsetFraction).rounded())
        }
        if hosting == nil {
            let id = UUID()
            contentID = id
            let view = NSHostingView(rootView: AnyView(LauncherView(model: model, maxShellHeight: availableShellHeight,
                                                                    onHeightChange: { [weak self] height in
                // Resize after SwiftUI's layout pass, and ignore callbacks from a hidden tree.
                self?.resizeTask?.cancel()
                self?.resizeTask = Task { @MainActor [weak self] in
                    guard !Task.isCancelled else { return }
                    guard let self, self.contentID == id, self.hosting != nil else { return }
                    self.resize(to: height)
                }
            }, onChromeChange: { [weak self] chrome in
                guard let self, self.contentID == id, self.hosting != nil else { return }
                self.update(chrome)
            })
            // Layout changes before the asynchronous panel resize. Pin the shell
            // to the top of the current host rather than centering it for a frame.
            .frame(maxHeight: .infinity, alignment: .top)))
            // The controller owns the window frame; preferredContentSize alone does not resize it.
            view.sizingOptions = []
            // Give SwiftUI a stable canvas. Resizing the NSHostingView itself
            // produces an intermediate centered layout for AppKit's field editor.
            // Only the container/window resize; a flexible bottom margin keeps
            // the fixed-height canvas anchored to the window top.
            shellHeight = LauncherLayout.inputHeight
            targetShellHeight = shellHeight
            resultReveal.set(Double(shellHeight))
            let size = NSSize(width: LauncherLayout.toolbarWidth, height: shellHeight)
            let container = NSView(frame: NSRect(origin: .zero, size: size))
            container.clipsToBounds = true
            view.frame = NSRect(x: 0, y: size.height - availableShellHeight,
                                width: size.width, height: availableShellHeight)
            view.autoresizingMask = [.width, .minYMargin]
            container.addSubview(view)
            panel.setContentSize(size)
            panel.contentView = WindowSurface.glassContentView(container, cornerRadius: LauncherLayout.shellCornerRadius)
            hosting = view
        }
        layoutSurfaces()
        panel.makeKeyAndOrderFront(nil)
        updateOutsideClickDismissal()
    }

    private func updateOutsideClickDismissal() {
        guard panel.isVisible else { outsideClickDismissal.hide(); return }
        outsideClickDismissal.show(below: panel, contains: { [weak self] point in
            guard let self else { return false }
            let surfaces = [self.panel]
            return surfaces.contains { $0.isVisible && !$0.ignoresMouseEvents && $0.alphaValue > 0 && $0.frame.contains(point) }
        }, dismiss: { [weak self] in self?.hide() })
    }

    private func update(_ next: LauncherChrome) {
        let previous = chrome
        chrome = next
        if next.toast != previous.toast { setToast(next.toast) }
        layoutSurfaces()
    }

    private func setToast(_ message: String?) {
        guard let message else { toastPanel.remove(); return }
        let view = ClipboardStatusToast(message: message)
        toastPanel.setSurface(view, size: SurfacePanel.fittingSize(of: view, maxWidth: LauncherLayout.toolbarWidth - 48),
                              cornerRadius: ClipboardStatusToast.cornerRadius, glass: false)
        layoutSurfaces()
        panel.addChildWindow(toastPanel, ordered: .above)
    }

    /// Places every surface from the toolbar origin. Child windows follow the
    /// parent's origin automatically, so they are reset after each shell move.
    private func layoutSurfaces() {
        let width = LauncherLayout.toolbarWidth
        let height = shellHeight.rounded()
        let frame = NSRect(x: origin.x, y: origin.y - height, width: width, height: height)
        if panel.frame != frame {
            // Let AppKit draw after laying out the new content size instead of forcing
            // a display of the intermediate field-editor/hosting-view geometry.
            panel.setFrame(frame, display: false)
            // The panel's origin and content layout must change in the same main-
            // actor turn; otherwise the live editor briefly stays at the old height.
            hosting?.layoutSubtreeIfNeeded()
            panel.invalidateShadow()
        }
        if let surface = panel.contentView {
            WindowSurface.updateCorners(of: surface,
                radius: LauncherLayout.shellCornerRadius, circular: true)
        }
        if toastPanel.isVisible {
            let size = toastPanel.frame.size
            toastPanel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.maxY + 12))
        }
    }

    private func resize(to contentHeight: CGFloat) {
        let height = min(availableShellHeight, max(LauncherLayout.inputHeight, ceil(contentHeight)))
        guard targetShellHeight != height else { return }
        targetShellHeight = height
        // AppKit's origin is at the bottom left; the input stays anchored while expanding down.
        // Step the actual glass window, preserving the fixed hosting canvas and
        // field editor. Retarget from the current height when another batch arrives.
        if panel.isVisible, height > LauncherLayout.inputHeight,
           !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            resultReveal.animate(to: Double(height), response: 0.18, damping: 1, in: panel)
        } else {
            resultReveal.set(Double(height))
        }
    }

    /// Hiding releases the SwiftUI trees and the result payloads (panel resource scope).
    func hide() {
        guard panel.isVisible, !hiding else { return }
        hiding = true
        defer { hiding = false }
        outsideClickDismissal.hide()
        resultReveal.stop()
        for surface in [toastPanel] { surface.remove() }
        panel.orderOut(nil)
        resizeTask?.cancel()
        resizeTask = nil
        contentID = UUID()
        chrome = LauncherChrome()
        model.reset()
        panel.contentView = nil
        hosting = nil
    }
}

struct LauncherView: View {
    @Bindable var model: LauncherModel
    var maxShellHeight: CGFloat = CGFloat(WindowMetrics.launcherMaxHeight)
    var onHeightChange: (CGFloat) -> Void = { _ in }
    var onChromeChange: (LauncherChrome) -> Void = { _ in }
    @State private var statusHeight: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    private var shellShape: RoundedRectangle {
        // Preserve the same circular corners before and after results expand.
        RoundedRectangle(cornerRadius: LauncherLayout.shellCornerRadius, style: .circular)
    }

    private var inputHeight: CGFloat { LauncherLayout.inputHeight }
    private var chrome: LauncherChrome {
        LauncherChrome(toast: model.toast)
    }

    var body: some View {
        searchShell
            .overlayPreferenceValue(LauncherMoreAnchorKey.self) { anchor in
                GeometryReader { geometry in
                    if let anchor {
                        let rect = geometry[anchor]
                        let availableHeight = max(32, rect.maxY - 12)
                        let height = min(availableHeight, LauncherMorphingActions.menuHeight(actionCount: model.secondaryActions.count))
                        let hitRect = CGRect(x: rect.maxX - LauncherLayout.actionsMenuWidth,
                                             y: geometry.size.height - rect.maxY,
                                             width: LauncherLayout.actionsMenuWidth, height: height)
                        let surfaceWidth = model.isActionsMenuPresented ? LauncherLayout.actionsMenuWidth : rect.width
                        let surfaceHeight = model.isActionsMenuPresented ? height : rect.height
                        LauncherMorphingActions(model: model, availableHeight: availableHeight)
                            .frame(width: surfaceWidth, height: surfaceHeight, alignment: .bottomTrailing)
                            .position(x: rect.maxX - surfaceWidth / 2, y: rect.maxY - surfaceHeight / 2)
                            .onChange(of: hitRect, initial: true) { _, frame in model.actionsMenuFrame = frame }
                    }
                }
            }
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: onHeightChange)
            .onChange(of: chrome, initial: true) { _, chrome in onChromeChange(chrome) }
    }

    private var searchShell: some View {
        VStack(spacing: 0) {
            HStack(spacing: LauncherLayout.inputSpacing) {
                if let folder = model.folderScope {
                    HStack(spacing: 6) {
                        Image(nsImage: ToolService.launcherIcon(filePath: folder.path))
                            .resizable().frame(width: 24, height: 24)
                        Text(folder.lastPathComponent)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1).truncationMode(.tail)
                    }
                    .frame(maxWidth: LauncherLayout.folderScopeMaxWidth, alignment: .leading)
                    .frame(height: LauncherLayout.folderScopeHeight)
                    .fixedSize(horizontal: true, vertical: false)
                    .help(folder.path)
                    .accessibilityLabel(folder.path)
                } else if model.hasScope {
                    commandIcon
                        .frame(width: 24, height: 24)
                        .accessibilityLabel(model.filter != .all ? NSLocalizedString(model.filter.title, tableName: "Launcher", comment: "Launcher filter") : model.isTerminalScope ? NSLocalizedString("终端命令", comment: "") : model.isTabScope ? NSLocalizedString("搜索开启的标签页", comment: "") : model.isBookmarkScope ? NSLocalizedString("搜索书签", comment: "") : model.isAIScope ? NSLocalizedString("AI 搜索", comment: "") : model.isLinkScope ? NSLocalizedString("搜索链接", comment: "") : model.commandInput.map { NSLocalizedString($0.command.name, comment: "Built-in website command") } ?? NSLocalizedString("关键词命令", comment: ""))
                }
                LauncherSearchField(
                    text: Binding(get: { model.inputText }, set: { model.inputText = $0 }),
                    fontSize: 16,
                    textColor: NSColor(ThemeColor.kText.color(for: colorScheme)),
                    placeholder: NSLocalizedString("搜索或输入你的任务", comment: "Launcher empty input placeholder"),
                    placeholderColor: NSColor(ThemeColor.kTextSubtlest.color(for: colorScheme)),
                    completion: model.calculationCompletion,
                    backspaceOnEmpty: model.backspaceOnEmptyInput,
                    move: model.move,
                    submit: { model.submit($0 ? .submitToAI : .executeSelection) },
                    copyPath: model.copySelectedPath,
                    revealInFinder: model.revealSelectionInFinder,
                    copyPathShortcut: model.actionPreferences.copyPathHotKey,
                    revealInFinderShortcut: model.actionPreferences.revealInFinderHotKey,
                    enterFolder: model.enterSelectedFolder
                )
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                searchIcon
            }
            .padding(.leading, LauncherLayout.inputLeadingPadding)
            .padding(.trailing, LauncherLayout.inputTrailingPadding)
            .frame(height: inputHeight)

            if let t = model.terminal {
                inputDivider
                TerminalOutputView(session: t, stop: model.stopTerminal)
            } else if let calculation = model.calculation {
                inputDivider
                CalculationView(expression: calculation.expression, result: calculation.result)
                    .frame(height: LauncherLayout.currencyCardHeight)
                    .padding(.bottom, LauncherLayout.actionBarHeight)
                    .overlay(alignment: .bottom) { LauncherActionBar(model: model) }
            } else if let conversion = model.unitConversion {
                inputDivider
                ConversionPairView {
                    ConversionValueCard(title: conversion.fromSymbol, amount: Calculator.format(conversion.input))
                } destination: {
                    ConversionValueCard(title: conversion.toSymbol,
                                        amount: Calculator.format((conversion.value * 1e6).rounded() / 1e6))
                }
                .frame(height: LauncherLayout.currencyCardHeight)
            } else if case .converted(let value, _, _, _, let query) = model.currencyConversion {
                inputDivider
                CurrencyConversionView(query: query, value: value)
                    .frame(height: LauncherLayout.currencyCardHeight)
                if model.results.contains(where: { $0.source == .currency && $0.target.identifier != query.to }) {
                    ResultList(model: model, maxHeight: maxShellHeight - inputHeight
                               - LauncherLayout.dividerHeight - LauncherLayout.currencyCardHeight - statusHeight,
                               excludedCurrencyCode: query.to)
                }
            } else if !model.results.isEmpty {
                inputDivider
                ResultList(model: model, maxHeight: maxShellHeight
                           - inputHeight - LauncherLayout.dividerHeight - statusHeight)
            }
            if let s = model.status {
                Text(s).font(.system(size: 14)).foregroundStyle(ThemeColor.kTextSubtle)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, LauncherLayout.inputLeadingPadding)
                    .padding(.trailing, LauncherLayout.inputTrailingPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { statusHeight = $0 }
            }
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(ThemeColor.kText.color(for: colorScheme))
        // Blank input/result areas must belong to the shell's pointer region.
        .contentShape(shellShape)
        .clipShape(shellShape)
        .windowSurfaceBackground(in: shellShape)
        .contentShape(shellShape)
        .onChange(of: model.status) { _, status in
            if status == nil { statusHeight = 0 }
        }
    }
    private var searchIcon: some View {
        Image(mingCute: "magnifyingglass", size: LauncherLayout.searchIconSize)
            .foregroundStyle(ThemeColor.kIconSubtle.color(for: colorScheme))
            .frame(width: LauncherLayout.inputAccessoryWidth, height: LauncherLayout.inputAccessoryHeight)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var commandIcon: some View {
        if model.filter != .all {
            LauncherFunctionIcon(kind: .searchCommand(model.filter.rawValue))
        } else if model.isTerminalScope {
            CommandIcon(terminalIcon: model.terminalIcon)
        } else if model.isTabScope {
            LauncherFunctionIcon(kind: .tabs)
        } else if model.isBookmarkScope {
            LauncherFunctionIcon(kind: .bookmark)
        } else if model.isAIScope {
            LauncherFunctionIcon(kind: .ai)
        } else if model.isLinkScope {
            LauncherFunctionIcon(kind: .link)
        } else if let command = model.commandInput?.command {
            CommandIcon(keyword: KeywordCommand.builtIn.first { $0.urlTemplate == command.urlTemplate }?.keyword ?? command.keyword)
        } else {
            Image(mingCute: "globe", size: 20).foregroundStyle(ThemeColor.kIcon)
        }
    }

    private var inputDivider: some View {
        Rectangle().fill(ThemeColor.kBorder)
            .frame(height: LauncherLayout.dividerHeight)
            .padding(.horizontal, 28)
    }

}

/// The input field owns editing and Return still copies the computed result.
private struct CalculationView: View {
    let expression: String
    let result: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(expression)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(ThemeColor.kTextSubtle)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(expression)
            Text(result)
                .font(.system(size: 28, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(ThemeColor.kText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .help(result)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeColor.kBackgroundNeutral,
                    in: RoundedRectangle(cornerRadius: LauncherLayout.rowCornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(expression) = \(result)")
        .padding(.horizontal, LauncherLayout.inputLeadingPadding)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }
}

/// A read-only conversion pair; the input field owns editing.
private struct CurrencyConversionView: View {
    let query: CurrencyQuery
    let value: Double

    var body: some View {
        ConversionPairView {
            currency(code: query.from, amount: query.amount)
        } destination: {
            currency(code: query.to, amount: value)
        }
    }

    private func currency(code: String, amount: Double) -> some View {
        ConversionValueCard(title: code, subtitle: CurrencyPresentation.name(for: code),
                            flag: CurrencyPresentation.flag(for: code),
                            amount: amount.formatted(.number.precision(.fractionLength(0...2))))
    }
}

/// Units and currencies share the same read-only two-card layout.
private struct ConversionPairView<Source: View, Destination: View>: View {
    @ViewBuilder var source: Source
    @ViewBuilder var destination: Destination

    var body: some View {
        HStack(spacing: 12) {
            source
            Image(mingCute: "arrow.left.arrow.right", size: 16)
                .foregroundStyle(ThemeColor.kIcon)
                .accessibilityHidden(true)
            destination
        }
        .padding(.horizontal, LauncherLayout.inputLeadingPadding)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }
}

private struct ConversionValueCard: View {
    let title: String
    var subtitle: String? = nil
    var flag: String? = nil
    let amount: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let flag {
                    Text(flag).font(.system(size: 22)).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ThemeColor.kText)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(ThemeColor.kTextSubtle)
                            .lineLimit(1)
                    }
                }
            }
            .frame(height: 34, alignment: .leading)
            Text(amount)
                .font(.system(size: 28, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(ThemeColor.kText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ThemeColor.kBackgroundNeutral,
                    in: RoundedRectangle(cornerRadius: LauncherLayout.rowCornerRadius))
        .accessibilityElement(children: .combine)
    }
}

private struct ResultList: View {
    @Bindable var model: LauncherModel
    let maxHeight: CGFloat
    var excludedCurrencyCode: String? = nil
    @State private var retainedHeight: CGFloat = 0
    @State private var selectionFromPointer = false
    @State private var lastSelectionPointerLocation = NSEvent.mouseLocation
    @State private var isRevealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct LayoutRequest: Equatable {
        let query: String
        let height: CGFloat
        let isSearching: Bool
    }

    private var visibleResults: [SearchResult] {
        model.results.filter { $0.source != .currency || $0.target.identifier != excludedCurrencyCode }
    }

    private var sections: [String] {
        var seen = Set<String>()
        return visibleResults.compactMap { seen.insert(Self.section(for: $0)).inserted ? Self.section(for: $0) : nil }
    }

    private var showsHeaders: Bool {
        // The AI fallback is an action, not another kind of local match.
        let resultSections = Set(visibleResults.filter { $0.source != .askAI }.map(Self.section(for:)))
        return !model.hasScope && resultSections.count > 1
    }

    private var footerHeight: CGFloat { model.primaryLauncherAction == nil ? 0 : LauncherLayout.actionBarHeight }
    private var bottomPadding: CGFloat { LauncherLayout.listBottomPadding + footerHeight }

    private var height: CGFloat {
        let rows = CGFloat(visibleResults.count) * LauncherLayout.rowHeight
        let headers = showsHeaders ? CGFloat(sections.count) * LauncherLayout.sectionHeaderHeight : 0
        // Headers share the ten-row budget. Short result lists still size to their content.
        let listHeightLimit = CGFloat(LauncherLayout.maxVisibleResults) * LauncherLayout.rowHeight
        return min(rows + headers + bottomPadding, listHeightLimit, maxHeight)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Search batches are capped; realize their anchors so keyboard
                // navigation can reveal rows in sections below the viewport.
                VStack(spacing: 0) {
                    ForEach(sections, id: \.self) { source in
                        VStack(spacing: 0) {
                            if showsHeaders {
                                Text(source).font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(ThemeColor.kTextSubtle)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 6).padding(.bottom, 4)
                                    .frame(height: LauncherLayout.sectionHeaderHeight)
                            }
                            ForEach(Array(model.results.enumerated()).filter { Self.section(for: $0.element) == source && ($0.element.source != .currency || $0.element.target.identifier != excludedCurrencyCode) }, id: \.element.id) { i, r in
                                if r.source == .currency {
                                    ResultRow(result: r, selected: false, keyword: nil)
                                        .accessibilityLabel(r.title)
                                        .padding(.bottom, r.id == visibleResults.last?.id ? bottomPadding : 0)
                                        .id(r.id)
                                } else {
                                    Button {
                                        model.selection = i
                                        model.submit(.executeSelection)
                                    } label: {
                                        ResultRow(result: r, selected: i == model.selection, keyword: model.keyword(for: r),
                                                  terminalIcon: model.terminalIcon, applicationIconPath: model.windowApplicationPath(for: r))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(r.title)
                                    .accessibilityAddTraits(i == model.selection ? .isSelected : [])
                                    .onHover { inside in
                                        guard inside, !model.isActionsMenuPresented else { return }
                                        let location = NSEvent.mouseLocation
                                        // Keyboard scrolling moves rows under a stationary pointer.
                                        // Only a moved pointer may take over the selection.
                                        guard location != lastSelectionPointerLocation else { return }
                                        lastSelectionPointerLocation = location
                                        guard model.selection != i else { return }
                                        selectionFromPointer = true
                                        model.selection = i
                                    }
                                    // Keep enough scrollable clearance for the final row
                                    // to move above the floating controls.
                                    .padding(.bottom, r.id == visibleResults.last?.id ? bottomPadding : 0)
                                    .id(r.id)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, LauncherLayout.listHorizontalPadding)
            }
            .scrollIndicators(.hidden)
            .mask(alignment: .bottom) {
                GeometryReader { geometry in
                    let fade = footerHeight / max(1, geometry.size.height)
                    LinearGradient(stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: max(0, 1 - fade - 0.06)),
                        .init(color: .clear, location: max(0, 1 - fade * 0.35)),
                        .init(color: .clear, location: 1)
                    ], startPoint: .top, endPoint: .bottom)
                }
            }
            .overlay(alignment: .bottom) {
                if footerHeight > 0 { LauncherActionBar(model: model) }
            }
            .frame(height: min(maxHeight, max(height, retainedHeight)))
            .task(id: LayoutRequest(query: model.query, height: height, isSearching: model.isSearching)) {
                let target = height
                if target < retainedHeight {
                    // A replacement query can temporarily have fewer matching rows.
                    // Hold their footprint until typing/batch delivery settles so
                    // the glass/window does not collapse and expand per character.
                    guard !model.isSearching else { return }
                    do { try await Task.sleep(for: .milliseconds(200)) }
                    catch { return }
                }
                guard !Task.isCancelled else { return }
                retainedHeight = target
            }
            .onChange(of: model.selection) { _, s in
                // Hover must select the row without moving it away from the pointer.
                if selectionFromPointer {
                    selectionFromPointer = false
                    return
                }
                guard model.results.indices.contains(s) else { return }
                proxy.scrollTo(model.results[s].id, anchor: .center)
            }
        }
        .onChange(of: model.isActionsMenuPresented) { _, _ in
            // Revealing a row under the transforming surface is not pointer movement.
            lastSelectionPointerLocation = NSEvent.mouseLocation
        }
        // Only reveal the list on insertion. Provider batches, typing and
        // keyboard selection must not restart the entrance or animate rows.
        .opacity(isRevealed ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: reduceMotion ? 0.10 : 0.18)) {
                isRevealed = true
            }
        }
    }

    private static func section(for result: SearchResult) -> String {
        if QuitAskyCommand.isResult(result) { return title(.app) }
        if ["search-command", "tab-search"].contains(result.target.kind) { return NSLocalizedString("搜索指令", comment: "") }
        if ["keyword-match", "launcher-alias"].contains(result.target.kind) { return NSLocalizedString("别名匹配", comment: "") }
        switch result.source {
        case .app, .link, .bookmark: return title(.app)
        default: return title(result.source)
        }
    }

    private static func title(_ source: SearchSource) -> String {
        switch source {
        case .app: NSLocalizedString("APP 应用", comment: "")
        case .file: NSLocalizedString("文件文档", comment: "")
        case .link: NSLocalizedString("链接", comment: "")
        case .bookmark: NSLocalizedString("书签", comment: "")
        case .chromeTab: NSLocalizedString("Chrome 标签页", comment: "")
        case .shortcut: NSLocalizedString("快捷指令", comment: "")
        case .keyword: NSLocalizedString("默认搜索", comment: "")
        case .askAI: "AI"
        case .calculator, .conversion, .currency: NSLocalizedString("计算与换算", comment: "")
        case .terminal: NSLocalizedString("终端命令", comment: "")
        case .clipboard: NSLocalizedString("剪贴板", comment: "")
        }
    }
}

private struct ResultRow: View {
    let result: SearchResult
    let selected: Bool
    let keyword: String?
    var terminalIcon: NSImage?
    var applicationIconPath: String?

    var body: some View {
        HStack(spacing: 12) {
            icon.frame(width: LauncherLayout.rowIconSize, height: LauncherLayout.rowIconSize)
            Text(keyword == nil ? result.title : result.title.components(separatedBy: "：").first ?? result.title)
                .font(.system(size: 14)).lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(ThemeColor.kText)
                .layoutPriority(1)
            if let keyword {
                Text(keyword).font(.system(size: 12)).lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(ThemeColor.kTextSubtle)
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(ThemeColor.kBackgroundNeutral,
                                in: RoundedRectangle(cornerRadius: 10))
            }
            Spacer(minLength: 12)
            Text(typeLabel)
                .font(.system(size: 12))
                .foregroundStyle(ThemeColor.kTextSubtlest)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 160, alignment: .trailing)
                .layoutPriority(2)
        }
        .padding(.horizontal, LauncherLayout.rowHorizontalPadding)
        .frame(height: LauncherLayout.rowHeight)
        .background(result.source == .currency ? AnyShapeStyle(.clear) :
                        selected ? AnyShapeStyle(ThemeColor.kBackgroundSelected) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: LauncherLayout.rowCornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: LauncherLayout.rowCornerRadius))
    }

    private var typeLabel: String {
        if result.target.kind == "application-window" {
            return NSLocalizedString("窗口", tableName: "Launcher", comment: "Result type")
        }
        let key: String
        switch result.source {
        case .app: key = "应用"
        case .file:
            return ToolService.launcherFileType(filePath: result.target.identifier)
                ?? NSLocalizedString("文件", tableName: "Launcher", comment: "Result type")
        case .link: key = "链接"
        case .bookmark: key = "书签"
        case .chromeTab: key = "标签页"
        case .clipboard: key = "剪贴板"
        case .keyword: key = "命令"
        case .calculator: key = "计算"
        case .conversion: key = "单位换算"
        case .currency: key = "汇率"
        case .terminal: key = "终端命令"
        case .shortcut: key = "快捷指令"
        case .askAI: return "AI"
        }
        return NSLocalizedString(key, tableName: "Launcher", comment: "Result type")
    }

    @ViewBuilder private var icon: some View {
        if result.target.kind == "search-command" {
            LauncherFunctionIcon(kind: .searchCommand(result.target.identifier))
        } else if result.target.kind == "application-window", let applicationIconPath, !applicationIconPath.isEmpty {
            Image(nsImage: ToolService.launcherIcon(filePath: applicationIconPath)).resizable().scaledToFit()
        } else if QuitAskyCommand.isResult(result) {
            LauncherFunctionIcon(kind: .quit)
        } else {
            sourceIcon
        }
    }

    @ViewBuilder private var sourceIcon: some View {
        switch result.source {
        case .app, .file:
            Image(nsImage: ToolService.launcherIcon(filePath: result.target.identifier)).resizable().scaledToFit()
        case .shortcut:
            DataSourceIcon(source: .shortcuts)
        case .chromeTab:
            LauncherFunctionIcon(kind: .tabs)
        case .terminal:
            CommandIcon(terminalIcon: terminalIcon)
        case .currency:
            if let flag = CurrencyPresentation.flag(for: result.target.identifier) {
                Text(flag).font(.system(size: LauncherLayout.rowIconSize))
                    .accessibilityLabel(CurrencyPresentation.name(for: result.target.identifier))
            } else {
                Image(mingCute: Self.symbol(.currency), size: LauncherLayout.rowIconSize).foregroundStyle(ThemeColor.kIcon)
            }
        case .link:
            LauncherFunctionIcon(kind: .link)
        case .calculator:
            LauncherFunctionIcon(kind: .calculator)
        case .conversion:
            LauncherFunctionIcon(kind: .conversion)
        case .askAI:
            LauncherFunctionIcon(kind: .ai)
        case .bookmark, .keyword:
            if result.source == .keyword, let keyword, CommandIcon.Brand(rawValue: keyword) != nil {
                CommandIcon(keyword: keyword)
            } else if result.target.kind == "launcher-alias", result.primaryAction == .open {
                Image(nsImage: ToolService.launcherIcon(filePath: result.target.identifier)).resizable().scaledToFit()
            } else if result.target.kind == "launcher-alias", case .runShortcut = result.primaryAction {
                DataSourceIcon(source: .shortcuts)
            } else if result.target.kind == "search-command" {
                LauncherFunctionIcon(kind: .searchCommand(result.target.identifier))
            } else if result.target.kind == "bookmark-search" {
                LauncherFunctionIcon(kind: .bookmark)
            } else if case .openURL(let url) = result.primaryAction, let icon = ToolService.launcherBrowserIcon(for: url) {
                Image(nsImage: icon).resizable().scaledToFit()
            } else {
                Image(mingCute: "globe", size: LauncherLayout.rowIconSize).foregroundStyle(ThemeColor.kIcon)
            }
        default:
            Image(mingCute: Self.symbol(result.source), size: LauncherLayout.rowIconSize).foregroundStyle(ThemeColor.kIcon)
        }
    }

    static func symbol(_ s: SearchSource) -> String {
        switch s {
        case .chromeTab, .keyword: "globe"
        case .clipboard: "doc.on.clipboard"
        case .calculator: "equal.square"
        case .conversion: "arrow.left.arrow.right"
        case .currency: "dollarsign.arrow.circlepath"
        case .terminal: "terminal"
        case .shortcut: "square.stack.3d.up"
        case .askAI: "sparkles"
        case .app, .file, .link, .bookmark: "doc"
        }
    }
}

private struct TerminalOutputView: View {
    let session: TerminalSession
    let stop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("> \(session.command)").font(.system(.body, design: .monospaced)).lineLimit(1)
                Spacer()
                if session.handedOff {
                    Text(NSLocalizedString("已转到“终端”", comment: "")).textStyle(.secondary)
                } else if let code = session.exitCode {
                    Text(String(format: NSLocalizedString("退出码 %@", comment: ""), String(code))).textStyle(.secondary)
                        .foregroundStyle(code == 0 ? ThemeColor.kTextPositive : ThemeColor.kTextNegative)
                } else {
                    Button(NSLocalizedString("停止", comment: ""), action: stop)
                }
            }
            ScrollView {
                Text(session.output.isEmpty ? " " : session.output)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 260)
            if let spilled = session.spilled {
                Button(String(format: NSLocalizedString("完整输出已保存：%@", comment: ""), spilled.lastPathComponent)) { NSWorkspace.shared.activateFileViewerSelecting([spilled]) }
                    .buttonStyle(.link)
            }
        }
        .padding(12)
    }
}
