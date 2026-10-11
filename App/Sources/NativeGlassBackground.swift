import SwiftUI
import Theme

/// One system-managed frosted surface, with an opaque accessibility fallback.
private struct NativeGlassBackground<S: InsettableShape>: ViewModifier {
    let shape: S
    var interactive: Bool
    var forceOpaque: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var scheme

    private var opaque: Bool { forceOpaque || reduceTransparency || contrast == .increased }

    func body(content: Content) -> some View {
        content
            .background {
                if opaque { shape.fill(ThemeColor.kBackground.color(for: scheme, opaque: true)) }
            }
            // Apply glass to its content, as required by the native compositing model.
            // Regular supplies blur and the optical rim; Clear exposes background detail.
            .glassEffect(opaque ? .identity : interactive ? .regular.interactive() : .regular, in: shape)
            .overlay {
                if opaque {
                    shape.strokeBorder(ThemeColor.kText.color(for: scheme).opacity(0.55), lineWidth: 1)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
    }
}

extension View {
    func nativeGlassBackground<S: InsettableShape>(in shape: S, interactive: Bool = false,
                                                   forceOpaque: Bool = false) -> some View {
        modifier(NativeGlassBackground(shape: shape, interactive: interactive, forceOpaque: forceOpaque))
    }
}
