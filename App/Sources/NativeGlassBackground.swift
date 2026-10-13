import AppKit
import SwiftUI
import Theme

/// Debug previews exercise the pre-26 appearance without changing the host OS.
@MainActor
enum SurfaceCompatibility {
    @MainActor @Observable final class State {
        var liquidGlassEnabled = true
    }
    static let state = State()

    static var supportsLiquidGlass: Bool {
        #if DEBUG
        if CommandLine.arguments.contains("--preview-legacy-material") { return false }
        #endif
        if #available(macOS 26, *) { return true }
        return false
    }

    /// Pre-26 systems, or Liquid Glass turned off in settings, use blur plus a border.
    static var useLegacyMaterial: Bool {
        !supportsLiquidGlass || !state.liquidGlassEnabled
    }
}

/// One system-managed frosted surface, with an opaque accessibility fallback.
private struct NativeGlassBackground<S: InsettableShape>: ViewModifier {
    let shape: S
    var interactive: Bool
    var forceOpaque: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var scheme

    private var opaque: Bool { forceOpaque || reduceTransparency || contrast == .increased }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *), !SurfaceCompatibility.useLegacyMaterial {
            content
                .background {
                    if opaque { shape.fill(ThemeColor.kBackground.color(for: scheme, opaque: true)) }
                }
                .glassEffect(opaque ? .identity : interactive ? .regular.interactive() : .regular, in: shape)
                .overlay {
                    if opaque {
                        shape.strokeBorder(ThemeColor.kText.color(for: scheme).opacity(0.55), lineWidth: 1)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
        } else {
            content
                .background {
                    ZStack {
                        if !opaque { LegacyBackdropBlur() }
                        shape.fill(ThemeColor.kBackground.color(for: scheme, opaque: opaque))
                    }
                    .clipShape(shape)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
                .overlay {
                    shape.strokeBorder(opaque ? ThemeColor.kText.color(for: scheme).opacity(0.55)
                                       : ThemeColor.kBorder.color(for: scheme), lineWidth: 1)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
        }
    }
}

extension View {
    /// The caller reserves shadowPadding in its transparent window canvas.
    /// Cut out the source shape so the shadow never tints the glass interior.
    func floatingSurfaceShadow<S: Shape>(in shape: S) -> some View {
        modifier(DarkFloatingShadow(shape: shape))
    }

    func nativeGlassBackground<S: InsettableShape>(in shape: S, interactive: Bool = false,
                                                   forceOpaque: Bool = false) -> some View {
        modifier(NativeGlassBackground(shape: shape, interactive: interactive, forceOpaque: forceOpaque))
    }
}

private struct DarkFloatingShadow<S: Shape>: ViewModifier {
    let shape: S
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.background {
            shape.fill(.black)
                .shadow(color: .black.opacity(scheme == .dark ? 0.6 : 0.18), radius: LauncherLayout.shadowRadius,
                        x: 0, y: LauncherLayout.shadowOffsetY)
                .padding(LauncherLayout.shadowPadding)
                .mask {
                    Rectangle().overlay {
                        shape.fill(.black)
                            .padding(LauncherLayout.shadowPadding)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                }
                .padding(-LauncherLayout.shadowPadding)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// AppKit blurs the live content behind the window; its public API owns the radius.
private struct LegacyBackdropBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

private struct CompatibleGlassButtonStyle: ViewModifier {
    var prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *), !SurfaceCompatibility.useLegacyMaterial {
            if prominent { content.buttonStyle(.glassProminent) }
            else { content.buttonStyle(.glass) }
        } else {
            if prominent { content.buttonStyle(.borderedProminent) }
            else { content.buttonStyle(.bordered) }
        }
    }
}

extension View {
    func compatibleGlassButtonStyle(prominent: Bool = false) -> some View {
        modifier(CompatibleGlassButtonStyle(prominent: prominent))
    }
}

private struct SettingsVersionBackground: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *), !SurfaceCompatibility.useLegacyMaterial {
            content
        } else {
            content
                .scrollContentBackground(.hidden)
                .nativeGlassBackground(in: Rectangle())
        }
    }
}

extension View {
    func settingsVersionBackground() -> some View {
        modifier(SettingsVersionBackground())
    }
}
