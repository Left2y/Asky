import AppKit
import SwiftUI
import Contracts
import DirectActions
import Theme
import Router
import ToolService

enum LauncherLayout {
    // Keep empty and populated fields aligned to the populated search layout.
    static let topInsetFraction: CGFloat = 0.12
    static let bottomClearance: CGFloat = 24
    static let inputHeight: CGFloat = 64
    static let accessorySpacing: CGFloat = 12
    static let toolbarWidth = WindowMetrics.launcherWidth
    static let inputLeadingPadding: CGFloat = 28
    static let inputTrailingPadding: CGFloat = 28
    static let inputSpacing: CGFloat = 12
    static let searchIconSize: CGFloat = 17
    // Figma blur 80 maps to a 40 pt shadow radius. Reserve three radii
    // around the shell so the transparent NSPanel does not clip the falloff.
    static let shadowRadius: CGFloat = 40
    static let shadowOffsetY: CGFloat = 12
    static let shadowPadding: CGFloat = 132
    static let expandedCornerRadius = CGFloat(Radius.values["radius32"] ?? 32)
    static let dividerHeight: CGFloat = 1
    // Figma Spotlight Item 38:461: 694 × 50, 32 pt icon, 16 pt radius.
    static let currencyCardHeight: CGFloat = 146
    static let rowHeight: CGFloat = 50
    static let maxVisibleResults = 8
    static let sectionHeaderHeight: CGFloat = 52
    static let rowSpacing: CGFloat = 0
    static let listHorizontalPadding: CGFloat = 13
    static let listBottomPadding: CGFloat = 12
    static let rowHorizontalPadding: CGFloat = 16
    static let rowCornerRadius = CGFloat(Radius.values["radius16"] ?? 16)
}

/// Floating, non-activating launcher panel that still takes key focus for the input field.
final class LauncherPanel: NSPanel {
    var onEscape: () -> Void = {}
    var onBlur: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onCopyPath: () -> Bool = { false }

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0,
                                      width: LauncherLayout.toolbarWidth + LauncherLayout.shadowPadding * 2,
                                      height: LauncherLayout.inputHeight + LauncherLayout.shadowPadding * 2),
                   styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        // Keep AppKit from outlining the transparent glass envelope. Dark mode
        // draws its own shape shadow outside the glass compositing layer.
        hasShadow = SurfaceCompatibility.useLegacyMaterial
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
    }

    override func sendEvent(_ event: NSEvent) {
        if SettingsShortcut.matches(event) { onOpenSettings(); return }
        // Intercept before SwiftUI/field editor routing so ⌥⌘C never degrades to ⌘C.
        if CompletionTextField.isCopyPath(event),
           (firstResponder as? NSTextView)?.hasMarkedText() != true,
           onCopyPath() { return }
        if event.type == .scrollWheel,
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
    override func resignKey() {
        super.resignKey()
        onBlur()
    }
}

@MainActor
final class LauncherController {
    private let panel = LauncherPanel()
    private let outsideClickDismissal = OutsideClickDismissal()
    private let model: LauncherModel
    private var hosting: NSHostingView<AnyView>?
    private var contentID = UUID()
    private var resizeTask: Task<Void, Never>?
    private var hiding = false
    private var availableShellHeight = CGFloat(WindowMetrics.launcherMaxHeight)

    init(model: LauncherModel) {
        self.model = model
        panel.onEscape = { [weak self] in
            guard let self else { return }
            if self.model.isFilterMenuPresented { self.model.isFilterMenuPresented = false }
            else if self.model.hasScope { self.model.leaveCommand() }
            else { self.hide() }
        }
        panel.onBlur = { [weak self] in
            guard let self else { return }
            self.model.isFilterMenuPresented = false
            guard !self.model.isPinned else { return }
            self.hide()
        }
        panel.onCopyPath = { [weak model] in model?.copySelectedPath() ?? false }
        model.onHide = { [weak self] in self?.hide() }
        model.onPinChanged = { [weak self] in self?.updateOutsideClickDismissal() }
    }

    var onOpenSettings: () -> Void {
        get { panel.onOpenSettings }
        set { panel.onOpenSettings = newValue }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        model.rebuildProviders()
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let f = screen?.visibleFrame {
            availableShellHeight = min(CGFloat(WindowMetrics.launcherMaxHeight), floor(f.height * (1 - LauncherLayout.topInsetFraction) - LauncherLayout.bottomClearance))
        }
        if hosting == nil {
            let id = UUID()
            contentID = id
            let view = NSHostingView(rootView: AnyView(LauncherView(model: model, maxShellHeight: availableShellHeight) { [weak self] height in
                // Resize after SwiftUI's layout pass, and ignore callbacks from a hidden tree.
                self?.resizeTask?.cancel()
                self?.resizeTask = Task { @MainActor [weak self] in
                    guard !Task.isCancelled else { return }
                    guard let self, self.contentID == id, self.hosting != nil else { return }
                    self.resize(to: height)
                }
            }
            // Layout changes before the asynchronous panel resize. Pin the shell
            // to the top of the current host rather than centering it for a frame.
            .frame(maxHeight: .infinity, alignment: .top)))
            // The controller owns the window frame; preferredContentSize alone does not resize it.
            view.sizingOptions = []
            // Give SwiftUI a stable canvas. Resizing the NSHostingView itself
            // produces an intermediate centered layout for AppKit's field editor.
            // Only the transparent container/window resize; a flexible bottom
            // margin keeps the fixed-height canvas anchored to the window top.
            let canvasHeight = availableShellHeight + LauncherLayout.shadowPadding * 2
            let container = NSView(frame: NSRect(origin: .zero, size: panel.frame.size))
            view.frame = NSRect(x: 0, y: container.bounds.height - canvasHeight,
                                width: container.bounds.width, height: canvasHeight)
            view.autoresizingMask = [.width, .minYMargin]
            container.addSubview(view)
            panel.contentView = container
            hosting = view
        }
        // Anchor near the top of the pointer screen, leaving room for results below.
        if let f = screen?.visibleFrame {
            let w = LauncherLayout.toolbarWidth + LauncherLayout.shadowPadding * 2
            panel.setFrameTopLeftPoint(NSPoint(x: f.midX - w / 2,
                                              y: f.maxY - f.height * LauncherLayout.topInsetFraction + LauncherLayout.shadowPadding))
        }
        panel.makeKeyAndOrderFront(nil)
        updateOutsideClickDismissal()
    }

    private func updateOutsideClickDismissal() {
        guard panel.isVisible, !model.isPinned else { outsideClickDismissal.hide(); return }
        outsideClickDismissal.show(below: panel, contains: { [weak self] point in
            guard let self else { return false }
            return self.panel.frame.insetBy(dx: LauncherLayout.shadowPadding,
                                           dy: LauncherLayout.shadowPadding).contains(point)
        }, dismiss: { [weak self] in self?.hide() })
    }

    private func resize(to contentHeight: CGFloat) {
        let shadowSpace = LauncherLayout.shadowPadding * 2
        let height = min(availableShellHeight + shadowSpace,
                         max(LauncherLayout.inputHeight + shadowSpace, ceil(contentHeight)))
        var frame = panel.frame
        guard frame.height != height else { return }
        // AppKit's origin is at the bottom left. Keep the input anchored while expanding down.
        frame.origin.y = frame.maxY - height
        frame.size.height = height
        // Let AppKit draw after laying out the new content size instead of forcing
        // a display of the intermediate field-editor/hosting-view geometry.
        panel.setFrame(frame, display: false)
        // The panel's origin and content layout must change in the same main-
        // actor turn; otherwise the live editor briefly stays at the old height.
        hosting?.layoutSubtreeIfNeeded()
        panel.invalidateShadow()
    }

    /// Hiding releases the SwiftUI tree and the result payloads (panel resource scope).
    func hide() {
        guard panel.isVisible, !hiding else { return }
        hiding = true
        defer { hiding = false }
        outsideClickDismissal.hide()
        panel.orderOut(nil)
        resizeTask?.cancel()
        resizeTask = nil
        contentID = UUID()
        model.reset()
        panel.contentView = nil
        hosting = nil
    }
}

struct LauncherView: View {
    @Bindable var model: LauncherModel
    var maxShellHeight: CGFloat = CGFloat(WindowMetrics.launcherMaxHeight)
    var onHeightChange: (CGFloat) -> Void = { _ in }
    @State private var statusHeight: CGFloat = 0
    @State private var accessoriesVisible = false
    @State private var hoveredFilter: LauncherFilter?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var shellShape: RoundedRectangle {
        // At 64 pt high, the 32 pt corners already form the empty capsule.
        // Keep one material shape identity when results appear/disappear.
        RoundedRectangle(cornerRadius: LauncherLayout.expandedCornerRadius, style: .continuous)
    }

    private var hasInput: Bool { !model.query.isEmpty }
    private var inputHeight: CGFloat { LauncherLayout.inputHeight }
    private var showsAccessories: Bool { accessoriesVisible && !hasInput }
    private var searchWidth: CGFloat {
        LauncherLayout.toolbarWidth - (showsAccessories ? 2 * (inputHeight + LauncherLayout.accessorySpacing) : 0)
    }
    private var revealAnimation: Animation? {
        if reduceMotion { return nil }
        // Typing should recover the full input width immediately; keep the
        // more expressive spring only for the empty launcher's separation.
        return hasInput ? .smooth(duration: 0.18, extraBounce: 0)
            : .spring(response: 0.28, dampingFraction: 0.78)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            searchShell
                .simultaneousGesture(TapGesture().onEnded { model.isFilterMenuPresented = false })
                .animation(reduceMotion ? nil : .smooth(duration: hasInput ? 0.18 : 0.12), value: showsAccessories)
            HStack(spacing: LauncherLayout.accessorySpacing) {
                accessory("pin", selected: model.isPinned, index: 0,
                          label: model.isPinned ? "取消固定" : "固定窗口") {
                    model.isPinned.toggle()
                }
                accessory("line.3.horizontal.decrease", selected: model.filter != .all || model.isFilterMenuPresented,
                          index: 1, label: "筛选搜索") {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.22)) {
                        model.isFilterMenuPresented.toggle()
                    }
                }
            }
            .frame(width: LauncherLayout.toolbarWidth, height: inputHeight, alignment: .trailing)
        }
        .frame(width: LauncherLayout.toolbarWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: hasInput) { _, searching in
            if searching { model.isFilterMenuPresented = false }
        }
        .overlay(alignment: .topTrailing) {
            if model.isFilterMenuPresented && !hasInput {
                filterMenu
                    .padding(.top, inputHeight + 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
            }
        }
        .frame(minHeight: model.isFilterMenuPresented && !hasInput ? 320 : 0, alignment: .top)
        .padding(LauncherLayout.shadowPadding)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: onHeightChange)
        .task {
            if reduceMotion { accessoriesVisible = true; return }
            try? await Task.sleep(for: .milliseconds(20))
            guard !Task.isCancelled else { return }
            withAnimation(revealAnimation) {
                accessoriesVisible = true
            }
        }
    }

    private func accessory(_ symbol: String, selected: Bool, index: Int, label: String,
                           action: @escaping () -> Void) -> some View {
        let glintEnabled = showsAccessories && !reduceMotion
        return Button(action: action) {
            Image(systemName: symbol + (symbol == "pin" && selected ? ".fill" : ""))
                .font(.system(size: LauncherLayout.searchIconSize, weight: .regular))
                .foregroundStyle(selected ? ThemeColor.kText.color(for: colorScheme) : ThemeColor.kIconSubtle.color(for: colorScheme))
                .frame(width: inputHeight, height: inputHeight)
                .contentShape(.interaction, Circle())
        }
        .buttonStyle(LauncherAccessoryButtonStyle(size: inputHeight))
        .floatingSurfaceShadow(in: Circle())
        .overlay {
            // A single edge glint as each glass circle separates from the field.
            // Keep it out of the hit area and suppress it for reduced motion.
            Circle()
                .strokeBorder(.white, lineWidth: 1)
                .keyframeAnimator(initialValue: 0.0, trigger: showsAccessories) { edge, brightness in
                    edge.opacity(glintEnabled ? brightness : 0)
                } keyframes: { _ in
                    LinearKeyframe(0.0, duration: Double(1 - index) * 0.035 + 0.04)
                    LinearKeyframe(0.32, duration: 0.055)
                    CubicKeyframe(0.0, duration: 0.18)
                }
                .allowsHitTesting(false)
        }
        .scaleEffect(showsAccessories ? 1 : 0.82)
        .opacity(showsAccessories ? 1 : 0)
        .offset(x: showsAccessories || reduceMotion ? 0 : CGFloat(2 - index) * 28)
        .animation(reduceMotion ? nil : hasInput ? .smooth(duration: 0.18, extraBounce: 0)
            : .spring(response: 0.28, dampingFraction: 0.78).delay(Double(1 - index) * 0.035),
                   value: showsAccessories)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
        .allowsHitTesting(showsAccessories)
        .accessibilityHidden(!showsAccessories)
        .accessibilityLabel(NSLocalizedString(label, tableName: "Launcher", comment: "Launcher accessory"))
        .accessibilityValue(selected ? "On" : "Off")
        .help(NSLocalizedString(label, tableName: "Launcher", comment: "Launcher accessory"))
    }

    private var filterMenu: some View {
        VStack(spacing: 4) {
            ForEach(LauncherFilter.allCases) { filter in
                Button {
                    model.setFilter(filter)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: filter.icon).frame(width: 22)
                        Text(NSLocalizedString(filter.title, tableName: "Launcher", comment: "Launcher filter"))
                        Spacer()
                        if model.filter == filter { Image(systemName: "checkmark") }
                    }
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(model.filter == filter || hoveredFilter == filter ? ThemeColor.kInteractionHover.color(for: colorScheme) : .clear,
                            in: RoundedRectangle(cornerRadius: 12))
                .onHover { inside in
                    if inside { hoveredFilter = filter }
                    else if hoveredFilter == filter { hoveredFilter = nil }
                }
            }
        }
        .padding(8)
        .frame(width: 220)
        .foregroundStyle(ThemeColor.kText.color(for: colorScheme))
        .nativeGlassBackground(in: RoundedRectangle(cornerRadius: 24))
        .onDisappear { hoveredFilter = nil }
    }

    private var searchShell: some View {
        VStack(spacing: 0) {
            HStack(spacing: LauncherLayout.inputSpacing) {
                if model.hasScope {
                    commandIcon
                        .frame(width: 24, height: 24)
                        .accessibilityLabel(model.isTerminalScope ? NSLocalizedString("终端命令", comment: "") : model.isBookmarkScope ? NSLocalizedString("搜索书签", comment: "") : model.commandInput?.command.name ?? NSLocalizedString("关键词命令", comment: ""))
                }
                LauncherSearchField(
                    text: Binding(get: { model.inputText }, set: { model.inputText = $0 }),
                    fontSize: 18,
                    textColor: NSColor(ThemeColor.kText.color(for: colorScheme)),
                    placeholder: NSLocalizedString("搜索或输入你的任务", comment: "Launcher empty input placeholder"),
                    placeholderColor: NSColor(ThemeColor.kTextSubtle.color(for: colorScheme)),
                    completion: model.calculationCompletion,
                    backspaceOnEmpty: model.backspaceOnEmptyInput,
                    move: model.move,
                    submit: { model.submit($0 ? .submitToAI : .executeSelection) },
                    copyPath: model.copySelectedPath,
                    revealInFinder: model.revealSelectionInFinder
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
                Text(s).textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtle)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, LauncherLayout.inputLeadingPadding)
                    .padding(.trailing, LauncherLayout.inputTrailingPadding).padding(.vertical, 8)
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { statusHeight = $0 }
            }
        }
        .frame(width: searchWidth)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(ThemeColor.kText.color(for: colorScheme))
        // Blank input/result areas must belong to the shell's pointer region.
        .contentShape(shellShape)
        .clipShape(shellShape)
        .nativeGlassBackground(in: shellShape)
        .floatingSurfaceShadow(in: shellShape)
        .contentShape(shellShape)
        .onChange(of: model.status) { _, status in
            if status == nil { statusHeight = 0 }
        }
    }
    private var searchIcon: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: LauncherLayout.searchIconSize, weight: .regular))
            .foregroundStyle(ThemeColor.kIconSubtle.color(for: colorScheme))
            .frame(width: 19, height: 24)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var commandIcon: some View {
        if model.isTerminalScope {
            CommandIcon(terminalIcon: model.terminalIcon)
        } else if model.isBookmarkScope {
            Image("Bookmark").resizable().scaledToFit()
        } else if let command = model.commandInput?.command {
            CommandIcon(keyword: command.keyword)
        } else {
            Image(systemName: "globe").font(.system(size: 20)).foregroundStyle(ThemeColor.kIcon)
        }
    }

    private var inputDivider: some View {
        Rectangle().fill(ThemeColor.kBorder)
            .frame(height: LauncherLayout.dividerHeight)
            .padding(.horizontal, 28)
    }

}

private struct LauncherAccessoryButtonStyle: ButtonStyle {
    let size: CGFloat
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .nativeGlassBackground(in: Circle())
            .overlay {
                Circle()
                    .fill(ThemeColor.kInteractionHover.color(for: colorScheme))
                    .opacity(isEnabled ? (configuration.isPressed ? 1 : isHovered ? 0.6 : 0) : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            // Keep the material inside the button label so its whole circle
            // participates in the button's native press and release gesture.
            .contentShape(.interaction, Circle())
            .scaleEffect(configuration.isPressed && isEnabled ? 0.96 : 1)
            .onHover { isHovered = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: configuration.isPressed)
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
        HStack(spacing: 12) {
            currency(code: query.from, amount: query.amount)
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ThemeColor.kIcon)
                .accessibilityHidden(true)
            currency(code: query.to, amount: value)
        }
        .padding(.horizontal, LauncherLayout.inputLeadingPadding)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    private func currency(code: String, amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let flag = CurrencyPresentation.flag(for: code) {
                    Text(flag).font(.system(size: 22)).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(code).font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ThemeColor.kText)
                    Text(CurrencyPresentation.name(for: code))
                        .font(.system(size: 12))
                        .foregroundStyle(ThemeColor.kTextSubtle)
                        .lineLimit(1)
                }
            }
            Text(amount.formatted(.number.precision(.fractionLength(0...2))))
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

    private var height: CGFloat {
        let rows = CGFloat(visibleResults.count) * LauncherLayout.rowHeight
        let headers = showsHeaders ? CGFloat(sections.count) * LauncherLayout.sectionHeaderHeight : 0
        // Headers share the eight-row budget. Short result lists still size to their content.
        let listHeightLimit = CGFloat(LauncherLayout.maxVisibleResults) * LauncherLayout.rowHeight
        return min(rows + headers + LauncherLayout.listBottomPadding, listHeightLimit, maxHeight)
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
                                Text(source).font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(ThemeColor.kTextSubtle)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16).padding(.bottom, 12)
                                    .frame(height: LauncherLayout.sectionHeaderHeight)
                            }
                            ForEach(Array(model.results.enumerated()).filter { Self.section(for: $0.element) == source && ($0.element.source != .currency || $0.element.target.identifier != excludedCurrencyCode) }, id: \.element.id) { i, r in
                                if r.source == .currency {
                                    ResultRow(result: r, selected: false, keyword: nil)
                                        .accessibilityLabel(r.title)
                                        .padding(.bottom, r.id == visibleResults.last?.id ? LauncherLayout.listBottomPadding : 0)
                                        .id(r.id)
                                } else {
                                    Button {
                                        model.selection = i
                                        model.submit(.executeSelection)
                                    } label: {
                                        ResultRow(result: r, selected: i == model.selection, keyword: model.keyword(for: r), terminalIcon: model.terminalIcon)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(r.title)
                                    .accessibilityAddTraits(i == model.selection ? .isSelected : [])
                                    // Keep clearance inside the final row's scroll target,
                                    // so every selection uses the same minimal reveal.
                                    .padding(.bottom, r.id == visibleResults.last?.id ? LauncherLayout.listBottomPadding : 0)
                                    .id(r.id)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, LauncherLayout.listHorizontalPadding)
            }
            .scrollIndicators(.hidden)
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
                guard model.results.indices.contains(s) else { return }
                proxy.scrollTo(model.results[s].id)
            }
        }
    }

    private static func section(for result: SearchResult) -> String {
        if result.target.kind == "keyword-match" { return NSLocalizedString("别名匹配", comment: "") }
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
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            icon.frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(keyword == nil ? result.title : result.title.components(separatedBy: "：").first ?? result.title)
                        .font(.system(size: 14)).lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(ThemeColor.kText)
                    if let keyword {
                        Text(keyword).font(.system(size: 14)).lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundStyle(ThemeColor.kTextSubtle)
                            .padding(.horizontal, 6)
                            .frame(height: 22)
                            .background(ThemeColor.kBackgroundNeutral,
                                        in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .frame(height: 22, alignment: .leading)
                if keyword == nil, !result.subtitle.isEmpty {
                    Text(result.source == .app ? result.target.identifier : result.subtitle)
                        .font(.system(size: 12)).foregroundStyle(ThemeColor.kTextSubtlest).lineLimit(1)
                        .truncationMode(.tail)
                        .frame(height: 20, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, LauncherLayout.rowHorizontalPadding)
        .frame(height: LauncherLayout.rowHeight)
        .background(result.source == .currency ? AnyShapeStyle(.clear) :
                        hovering ? AnyShapeStyle(ThemeColor.kInteractionHover) :
                        selected ? AnyShapeStyle(ThemeColor.kBackgroundSelected) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: LauncherLayout.rowCornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: LauncherLayout.rowCornerRadius))
        .onHover { hovering = result.source != .currency && $0 }
    }

    @ViewBuilder private var icon: some View {
        switch result.source {
        case .app, .file:
            Image(nsImage: ToolService.launcherIcon(filePath: result.target.identifier)).resizable().scaledToFit()
        case .shortcut:
            DataSourceIcon(source: .shortcuts)
        case .chromeTab:
            DataSourceIcon(source: .chrome)
        case .terminal:
            CommandIcon(terminalIcon: terminalIcon)
        case .currency:
            if let flag = CurrencyPresentation.flag(for: result.target.identifier) {
                Text(flag).font(.system(size: 28))
                    .accessibilityLabel(CurrencyPresentation.name(for: result.target.identifier))
            } else {
                Image(systemName: Self.symbol(.currency)).font(.system(size: 28)).foregroundStyle(ThemeColor.kIcon)
            }
        case .link:
            Image("Link").resizable().scaledToFit()
        case .calculator, .askAI:
            Image(result.source == .calculator ? "Calculator" : "Agent").resizable().scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: .black.opacity(0.16), radius: 1, x: 0, y: 1)
                .padding(3)
        case .bookmark, .keyword:
            if result.source == .keyword, let keyword, CommandIcon.Brand(rawValue: keyword) != nil {
                CommandIcon(keyword: keyword)
            } else if result.target.kind == "launcher-alias", result.primaryAction == .open {
                Image(nsImage: ToolService.launcherIcon(filePath: result.target.identifier)).resizable().scaledToFit()
            } else if result.target.kind == "launcher-alias", case .runShortcut = result.primaryAction {
                DataSourceIcon(source: .shortcuts)
            } else if result.target.kind == "bookmark-search" {
                Image("Bookmark").resizable().scaledToFit()
            } else if case .openURL(let url) = result.primaryAction, let icon = ToolService.launcherBrowserIcon(for: url) {
                Image(nsImage: icon).resizable().scaledToFit()
            } else {
                Image(systemName: "globe").font(.system(size: 28)).foregroundStyle(ThemeColor.kIcon)
            }
        default:
            Image(systemName: Self.symbol(result.source)).font(.system(size: 28)).foregroundStyle(ThemeColor.kIcon)
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
