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

    static func updateCorners(of view: NSView, radius: CGFloat, circular: Bool) {
        view.layer?.cornerRadius = radius
        view.layer?.cornerCurve = circular ? .circular : .continuous
        // Native sheets put their dimming view beside the content, in AppKit's
        // window frame view. Clip that shared ancestor too, so the dimmer cannot
        // fill the transparent corners of a borderless surface.
        if let window = view.window, !window.styleMask.contains(.titled),
           window.contentView === view, let frameView = view.superview {
            frameView.wantsLayer = true
            frameView.layer?.cornerRadius = radius
            frameView.layer?.cornerCurve = circular ? .circular : .continuous
            frameView.layer?.masksToBounds = true
        }
        if #available(macOS 26, *), let glass = view as? GlassSurfaceView {
            glass.updateCorners(radius: radius, circular: circular)
        }
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
            let glass = GlassSurfaceView(frame: content.frame)
            glass.cornerRadius = cornerRadius
            glass.install(content, cornerRadius: cornerRadius)
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

/// System glass in a non-key window renders with the dimmer inactive
/// material. Child menu surfaces can never be key, so
/// next to the key shell they read as a darker material even over the same
/// backdrop. `matchesActiveAppearance` restores the highlight the system adds
/// to the active window's glass.
@available(macOS 26, *)
final class GlassSurfaceView: NSGlassEffectView {
    private let inactiveTint = InactiveGlassTintView(frame: .zero)
    private let wrapper = NSView(frame: .zero)

    var matchesActiveAppearance = false {
        didSet { inactiveTint.isHidden = !matchesActiveAppearance }
    }

    func updateCorners(radius: CGFloat, circular: Bool) {
        cornerRadius = radius
        let curve: CALayerCornerCurve = circular ? .circular : .continuous
        let layers: [NSView?] = [self, wrapper, wrapper.subviews.last]
        for view in layers.compactMap({ $0 }) {
            view.layer?.cornerRadius = radius
            view.layer?.cornerCurve = curve
        }
        inactiveTint.cornerRadius = radius
    }

    func install(_ content: NSView, cornerRadius: CGFloat) {
        wrapper.frame = bounds
        wrapper.autoresizingMask = [.width, .height]
        wrapper.wantsLayer = true
        wrapper.layer?.cornerRadius = cornerRadius
        wrapper.layer?.cornerCurve = .continuous
        wrapper.layer?.masksToBounds = true
        inactiveTint.frame = wrapper.bounds
        inactiveTint.autoresizingMask = [.width, .height]
        inactiveTint.cornerRadius = cornerRadius
        inactiveTint.isHidden = true
        wrapper.addSubview(inactiveTint)
        content.frame = wrapper.bounds
        content.autoresizingMask = [.width, .height]
        wrapper.addSubview(content)
        contentView = wrapper
    }
}

/// The measured lift between inactive and active light glass over a bright
/// backdrop. `.plusLighter` adds the layer instead of compositing it, which is
/// the only way to brighten the glass next to white without washing it out.
private struct AdditiveWhiteLift: View {
    var body: some View {
        Color.white.opacity(0.05).blendMode(.plusLighter)
    }
}

/// Hosts the additive fill without taking clicks from the button above it.
private final class PassiveHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Sits between the glass and its content and redraws what the active
/// material has over the inactive one: a uniform fill lift plus the specular
/// rim, which is strongest on the horizontal edges and faint on the sides.
/// The alphas are measured from screenshots of active vs inactive glass.
///
/// The light fill is additive rather than a translucent white layer. Over a
/// bright backdrop the inactive material is about 12 levels darker than the
/// active one; a normal white overlay saturates near white and adds nothing,
/// while an additive layer lifts one constant amount. Dark mode keeps the
/// alpha fill, which tracks the darker material.
private final class InactiveGlassTintView: NSView {
    var cornerRadius: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    private let lightFill = PassiveHostingView(rootView: AdditiveWhiteLift())

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        lightFill.frame = bounds
        lightFill.autoresizingMask = [.width, .height]
        addSubview(lightFill)
        updateFill()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Decoration only: never steal clicks from the button above it.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateFill()
    }

    private var isDark: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func updateFill() {
        // The additive layer replaces the alpha fill over bright backdrops.
        lightFill.isHidden = isDark
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext,
              bounds.width > 0, bounds.height > 0 else { return }
        let dark = isDark
        if dark {
            // Uniform difference between the active and inactive materials.
            ctx.setFillColor(white(0.05))
            ctx.fill(bounds)
        }
        // Rim bands: centre inset, width and edge alpha of each ring.
        let bands: [(inset: CGFloat, width: CGFloat, alpha: CGFloat)] = dark
            ? [(0.5, 1, 0.24), (1.5, 1, 0.055), (3.25, 2.5, 0.022)]
            : [(0.5, 1, 0.40), (1.5, 1, 0.085), (3.25, 2.5, 0.035)]
        for band in bands {
            let radius = max(0, cornerRadius - band.inset)
            let rect = bounds.insetBy(dx: band.inset, dy: band.inset)
            ctx.saveGState()
            ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius,
                               transform: nil))
            ctx.setLineWidth(band.width)
            ctx.replacePathWithStrokedPath()
            ctx.clip()
            // Top and bottom edges carry the highlight; the vertical sides
            // fade towards the middle.
            let stops: [(location: CGFloat, scale: CGFloat)] =
                [(0, 1), (0.20, 0.45), (0.35, 0.10), (0.65, 0.10), (0.80, 0.45), (1, 1)]
            let colors = stops.map { white(band.alpha * $0.scale) }
            if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                         colors: colors as CFArray,
                                         locations: stops.map(\.location)) {
                ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: bounds.maxY),
                                       end: CGPoint(x: 0, y: bounds.minY), options: [])
            }
            ctx.restoreGState()
        }
    }

    private func white(_ alpha: CGFloat) -> CGColor {
        NSColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha).cgColor
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
    /// Matches this surface's glass to the active appearance of the window
    /// that owns its visual group while that window is key.
    var matchesActiveAppearance: Bool {
        get {
            if #available(macOS 26, *), let glass = contentView as? GlassSurfaceView {
                return glass.matchesActiveAppearance
            }
            return false
        }
        set {
            if #available(macOS 26, *), let glass = contentView as? GlassSurfaceView {
                glass.matchesActiveAppearance = newValue
            }
        }
    }

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
        // Hosting a measured view can round glyph widths up by a point (notably
        // the toast's checkmark). Leave room so text cannot wrap after sizing.
        return NSSize(width: min(maxWidth, ceil(size.width) + 1), height: ceil(size.height))
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
