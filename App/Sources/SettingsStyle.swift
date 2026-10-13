import AppKit
import SwiftUI
import Theme

enum SettingsPalette {
    static func card(_ scheme: ColorScheme) -> Color {
        // Cards sit on the tinted glass; a strong white fill overwhelms it in light mode.
        scheme == .dark ? ThemeColor.kBackgroundNeutral.color(for: scheme)
            : ThemeColor.kBackground.color(for: scheme, opaque: true).opacity(0.18)
    }
    static func separator(_ scheme: ColorScheme) -> Color {
        ThemeColor.kBorder.color(for: scheme).opacity(scheme == .light ? 0.5 : 1)
    }
    static func surface(_ scheme: ColorScheme, opaque: Bool = false) -> Color {
        ThemeColor.kBackground.color(for: scheme, opaque: true).opacity(opaque ? 1 : 0.7)
    }
}

/// Shared template for every settings page: section headings and quiet inset cards.
struct SettingsForm<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(sections: content) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        if !section.header.isEmpty {
                            section.header
                                .font(.system(size: 14, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        VStack(spacing: 0) {
                            ForEach(subviews: section.content) { row in
                                if row.id != section.content.first?.id {
                                    Rectangle().fill(SettingsPalette.separator(scheme))
                                        .frame(height: 1).padding(.horizontal, 16)
                                }
                                row
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16).padding(.vertical, 12)
                            }
                        }
                        .background(SettingsPalette.card(scheme),
                                    in: RoundedRectangle(cornerRadius: 12))
                        if !section.footer.isEmpty {
                            section.footer.font(.system(size: 12)).foregroundStyle(ThemeColor.kTextSubtlest)
                        }
                    }
                }
            }
            .padding(20).padding(.top, -4)
        }
        .font(.system(size: 14))
        .foregroundStyle(ThemeColor.kText)
        .labeledContentStyle(SettingsLabelStyle())
        .textFieldStyle(.roundedBorder)
        .controlSize(.regular)
    }
}

private struct SettingsLabelStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 24) {
            configuration.label
            Spacer(minLength: 24)
            configuration.content
        }
    }
}

extension VerticalAlignment {
    /// Centers trailing controls on a labeled input's field rather than on the label + field stack.
    private enum SettingsInput: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat { d[VerticalAlignment.center] }
    }
    static let settingsInput = VerticalAlignment(SettingsInput.self)
}

/// Single-line fields scroll to keep the caret visible when text overflows.
private let SettingsInputWidth: CGFloat = 260

struct SettingsTextField: View {
    let title: String
    @Binding var text: String
    @Environment(\.colorScheme) private var scheme
    @FocusState private var focused: Bool
    var prompt: Text? = nil
    init(_ title: String, text: Binding<String>, prompt: Text? = nil) {
        self.title = title; _text = text; self.prompt = prompt
    }
    var body: some View {
        HStack(spacing: 24) {
            Text(title)
            Spacer(minLength: 24)
            TextField(title, text: $text, prompt: prompt).labelsHidden()
                .textFieldStyle(.plain).focused($focused)
                .settingsInputSurface(scheme: scheme, focused: focused)
                .frame(width: SettingsInputWidth)
        }
    }
}

struct SettingsSecureField: View {
    let title: String
    @Binding var text: String
    @Environment(\.colorScheme) private var scheme
    @FocusState private var focused: Bool
    var prompt: Text? = nil
    init(_ title: String, text: Binding<String>, prompt: Text? = nil) {
        self.title = title; _text = text; self.prompt = prompt
    }
    var body: some View {
        HStack(spacing: 24) {
            Text(title)
            Spacer(minLength: 24)
            SecureField(title, text: $text, prompt: prompt).labelsHidden()
                .textFieldStyle(.plain).focused($focused)
                .settingsInputSurface(scheme: scheme, focused: focused)
                .frame(width: SettingsInputWidth)
        }
    }
}

private extension View {
    func settingsInputSurface(scheme: ColorScheme, focused: Bool) -> some View {
        // Match the 24pt height of the native regular push buttons and pop-ups beside them.
        padding(.horizontal, 8).frame(height: 24)
            .background(scheme == .dark ? ThemeColor.kBackgroundNeutral.color(for: scheme)
                        : SettingsPalette.surface(scheme), in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(focused ? Color.accentColor : ThemeColor.kBorder.color(for: scheme),
                                  lineWidth: focused ? 2 : 1)
                    .allowsHitTesting(false)
            }
            .alignmentGuide(.settingsInput) { $0[VerticalAlignment.center] }
    }
}

struct SettingsBackdrop: View {
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    private var opaque: Bool { reduceTransparency || contrast == .increased }
    var body: some View {
        if opaque {
            Rectangle().fill(SettingsPalette.surface(scheme, opaque: true))
        } else if #available(macOS 26, *), !SurfaceCompatibility.useLegacyMaterial {
            SettingsRegularGlass(scheme: scheme, inactive: activeState == .inactive)
                .overlay(ThemeColor.kBackgroundNeutral.color(for: scheme).opacity(activeState == .inactive ? 0.5 : 1))
        } else {
            Color.clear.nativeGlassBackground(in: Rectangle())
        }
    }
}

/// Use AppKit's window-aware Regular glass, with the template background as tint.
@available(macOS 26, *)
private struct SettingsRegularGlass: NSViewRepresentable {
    let scheme: ColorScheme
    let inactive: Bool
    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.style = .regular
        view.cornerRadius = 32
        updateNSView(view, context: context)
        return view
    }
    func updateNSView(_ view: NSGlassEffectView, context: Context) {
        view.tintColor = NSColor(SettingsPalette.surface(scheme, opaque: true)).withAlphaComponent(inactive ? 0.55 : 0.25)
    }
}

/// A native AppKit push button, including the system bezel, focus and disabled states.
struct SettingsButton: View {
    let title: String
    let action: () -> Void
    let role: ButtonRole?
    var systemImage: String?
    var isLoading: Bool
    var isComplete: Bool
    var loadingTitle: String?
    var isBordered: Bool
    init(_ title: String, role: ButtonRole? = nil, systemImage: String? = nil,
         isLoading: Bool = false, isComplete: Bool = false, loadingTitle: String? = nil,
         isBordered: Bool = true, action: @escaping () -> Void) {
        self.title = title; self.role = role; self.systemImage = systemImage; self.action = action
        self.isLoading = isLoading; self.isComplete = isComplete; self.loadingTitle = loadingTitle
        self.isBordered = isBordered
    }
    var body: some View {
        SettingsPushButton(title: title, role: role, systemImage: systemImage,
                           hidesTitle: isLoading || isComplete, isBordered: isBordered, action: action)
            .fixedSize()
            .overlay {
                if isComplete { Image(systemName: "checkmark").accessibilityHidden(true) }
                else if isLoading {
                    if let loadingTitle { Text(loadingTitle).font(.system(size: 14)) }
                    else { ProgressView().controlSize(.small) }
                }
            }
    }
}

private struct SettingsPushButton: NSViewRepresentable {
    let title: String
    let role: ButtonRole?
    let systemImage: String?
    let hidesTitle: Bool
    let isBordered: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var enabled
    @Environment(\.controlSize) private var controlSize
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: title, target: context.coordinator, action: #selector(Coordinator.press))
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = .systemFont(ofSize: 14)
        return button
    }
    func updateNSView(_ button: NSButton, context: Context) {
        button.title = title
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: hidesTitle ? NSColor.clear : role == .destructive ? NSColor.systemRed :
                enabled ? NSColor.controlTextColor : NSColor.disabledControlTextColor
        ])
        button.controlSize = controlSize == .large || controlSize == .extraLarge ? .large : .regular
        button.image = systemImage.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
            .flatMap { isBordered ? $0 : $0.withSymbolConfiguration(.init(pointSize: 12, weight: .regular)) }
        button.imagePosition = systemImage == nil ? .noImage : title.isEmpty ? .imageOnly : .imageLeading
        button.contentTintColor = role == .destructive ? .systemRed : nil
        button.isBordered = isBordered
        button.isEnabled = enabled
        context.coordinator.action = action
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSButton, context: Context) -> CGSize? {
        nsView.intrinsicContentSize
    }
    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func press() { action() }
    }
}

struct SettingsCheckbox: NSViewRepresentable {
    let title: String
    @Binding var isOn: Bool
    @Environment(\.isEnabled) private var enabled

    func makeCoordinator() -> Coordinator { Coordinator(isOn: $isOn) }
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: context.coordinator,
                              action: #selector(Coordinator.toggle(_:)))
        button.font = .systemFont(ofSize: 14)
        return button
    }
    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.isOn = $isOn
        button.title = title
        button.state = isOn ? .on : .off
        button.isEnabled = enabled
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSButton, context: Context) -> CGSize? {
        nsView.intrinsicContentSize
    }
    final class Coordinator: NSObject {
        var isOn: Binding<Bool>
        init(isOn: Binding<Bool>) { self.isOn = isOn }
        @objc func toggle(_ sender: NSButton) { isOn.wrappedValue = sender.state == .on }
    }
}

struct SettingsChoice<Value: Hashable>: NSViewRepresentable {
    @Binding var selection: Value
    let options: [(Value, String)]
    var images: [Value: NSImage] = [:]
    @Environment(\.isEnabled) private var enabled
    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection, options: options) }
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 14)
        button.target = context.coordinator
        button.action = #selector(Coordinator.select(_:))
        return button
    }
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.selection = $selection
        context.coordinator.options = options
        button.isEnabled = enabled
        if button.itemTitles != options.map({ $0.1 }) {
            button.removeAllItems(); button.addItems(withTitles: options.map { $0.1 })
        }
        for (index, option) in options.enumerated() {
            button.item(at: index)?.image = images[option.0].map { image in
                let thumbnail = (image.copy() as? NSImage) ?? image
                thumbnail.size = NSSize(width: 16, height: 16)
                return thumbnail
            }
        }
        if let index = options.firstIndex(where: { $0.0 == selection }) { button.selectItem(at: index) }
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSPopUpButton, context: Context) -> CGSize? {
        nsView.intrinsicContentSize
    }
    final class Coordinator: NSObject {
        var selection: Binding<Value>
        var options: [(Value, String)]
        init(selection: Binding<Value>, options: [(Value, String)]) { self.selection = selection; self.options = options }
        @objc func select(_ sender: NSPopUpButton) {
            guard options.indices.contains(sender.indexOfSelectedItem) else { return }
            selection.wrappedValue = options[sender.indexOfSelectedItem].0
        }
    }
}
