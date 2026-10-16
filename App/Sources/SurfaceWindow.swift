import AppKit
import QuartzCore
import SwiftUI

/// Spotlight-style floating surfaces: each window frame is exactly one
/// surface, AppKit's own glass view fills it and the window server draws the
/// shadow from that shape. Nothing transparent surrounds the glass, so there
/// is no envelope for the shadow to trace and nothing drawn behind the glass.
@MainActor
enum WindowSurface {
    /// AppKit hosts the glass on macOS 26 with Liquid Glass on and no
    /// accessibility override; otherwise SwiftUI draws the fallback surface.
    static var usesNativeGlass: Bool {
        guard !SurfaceCompatibility.useLegacyMaterial else { return false }
        let workspace = NSWorkspace.shared
        return !workspace.accessibilityDisplayShouldReduceTransparency
            && !workspace.accessibilityDisplayShouldIncreaseContrast
    }

    /// Wraps `content` in the window-filling glass view when it applies.
    /// Both views are clipped to the rounded shape: the glass leaves faint
    /// alpha in the window corners, and the window server derives the shadow
    /// from any nonzero alpha, which shows as a square dark corner.
    static func glassContentView(_ content: NSView, cornerRadius: CGFloat) -> NSView {
        content.wantsLayer = true
        content.layer?.cornerRadius = cornerRadius
        content.layer?.cornerCurve = .continuous
        content.layer?.masksToBounds = true
        if #available(macOS 26, *), usesNativeGlass {
            let glass = NSGlassEffectView(frame: content.frame)
            glass.cornerRadius = cornerRadius
            content.frame = glass.bounds
            content.autoresizingMask = [.width, .height]
            glass.contentView = content
            glass.wantsLayer = true
            glass.layer?.cornerRadius = cornerRadius
            glass.layer?.cornerCurve = .continuous
            glass.layer?.masksToBounds = true
            return glass
        }
        content.autoresizingMask = [.width, .height]
        return content
    }
}

private struct WindowSurfaceBackground<S: InsettableShape>: ViewModifier {
    let shape: S

    @ViewBuilder
    func body(content: Content) -> some View {
        if WindowSurface.usesNativeGlass { content }
        else { content.nativeGlassBackground(in: shape) }
    }
}

extension View {
    /// Background for a view that fills its own `SurfacePanel`; the panel
    /// supplies native glass, so SwiftUI only draws the fallbacks.
    func windowSurfaceBackground<S: InsettableShape>(in shape: S) -> some View {
        modifier(WindowSurfaceBackground(shape: shape))
    }
}

/// Clicks in a panel that never becomes key still reach SwiftUI controls.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// A borderless panel sized to one surface. It never takes key focus, so the
/// owning panel keeps the text field while this one handles clicks.
final class SurfacePanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                   styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Installs `view` on native glass, or as an opaque surface when `glass` is false.
    func setSurface<V: View>(_ view: V, size: NSSize, cornerRadius: CGFloat, glass: Bool = true) {
        setContentSize(size)
        let host = FirstMouseHostingView(rootView: view)
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: size)
        contentView = glass ? WindowSurface.glassContentView(host, cornerRadius: cornerRadius) : host
        invalidateShadow()
    }

    /// The size SwiftUI wants for `view` within `width`.
    static func fittingSize<V: View>(of view: V, maxWidth: CGFloat) -> NSSize {
        let size = NSHostingController(rootView: view)
            .sizeThatFits(in: CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        return NSSize(width: ceil(size.width), height: ceil(size.height))
    }

    func remove() {
        parent?.removeChildWindow(self)
        orderOut(nil)
        contentView = nil
    }
}

/// Window frames cannot use SwiftUI springs, so this steps a damped spring on
/// the display link and reports the progress (which may overshoot 1).
@MainActor
final class SurfaceSpring: NSObject {
    private var link: CADisplayLink?
    private var startTime: CFTimeInterval?
    private var from = 0.0
    private var target = 0.0
    private var response = 0.28
    private var damping = 0.78
    private(set) var value = 0.0
    var onStep: (Double) -> Void = { _ in }

    func set(_ value: Double) {
        stop()
        self.value = value
        target = value
        onStep(value)
    }

    func animate(to target: Double, response: Double, damping: Double, in window: NSWindow) {
        guard target != self.target || link != nil else { return }
        stop()
        from = value
        self.target = target
        self.response = response
        self.damping = damping
        let link = window.displayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        startTime = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        let now = link.targetTimestamp
        let start = startTime ?? link.timestamp
        startTime = start
        let t = now - start
        let omega = 2 * Double.pi / response
        let progress: Double
        if damping >= 1 {
            progress = 1 - exp(-omega * t) * (1 + omega * t)
        } else {
            let decay = damping * omega
            let wd = omega * (1 - damping * damping).squareRoot()
            progress = 1 - exp(-decay * t) * (cos(wd * t) + decay / wd * sin(wd * t))
        }
        // Settled once the remaining motion is below a hundredth of a point.
        let settled = t > 2 || (t > response && abs(1 - progress) * abs(target - from) * 150 < 0.01)
        value = settled ? target : from + (target - from) * progress
        onStep(value)
        if settled { stop() }
    }
}
