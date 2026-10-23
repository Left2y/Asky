import AppKit
import SwiftUI

/// An ordinary native window, independent of the launcher's transient panels.
@MainActor
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let presentation = WindowPresentation()
    private let onStart: () -> Void

    init(onStart: @escaping () -> Void) { self.onStart = onStart }

    var isVisible: Bool { window?.isVisible == true }

    func show() {
        if let window { presentation.show(window); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
                              styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = NSLocalizedString("欢迎使用 Asky", comment: "")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .primary]
        window.delegate = self
        let hosting = NSHostingView(rootView: WelcomeView { [weak self] in
            guard let self else { return }
            self.window?.close()
            self.onStart()
        })
        hosting.safeAreaRegions = []
        window.contentView = hosting
        self.window = window
        window.center()
        presentation.show(window)
    }

    func windowWillClose(_ notification: Notification) {
        // Removing the hosting view cancels its task and releases animated content.
        window?.contentView = nil
        window = nil
    }
}

private struct WelcomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var ink: CGFloat = 0
    @State private var arrived = false
    @State private var drifting = false
    let onStart: () -> Void

    private var dark: Bool { colorScheme == .dark }
    private let colors: [Color] = [
        Color(red: 0.37, green: 0.53, blue: 0.93),
        Color(red: 0.61, green: 0.44, blue: 0.85),
        Color(red: 0.91, green: 0.48, blue: 0.63),
        Color(red: 0.96, green: 0.64, blue: 0.39)
    ]

    var body: some View {
        ZStack {
            Color(red: dark ? 0.085 : 0.985, green: dark ? 0.09 : 0.98, blue: dark ? 0.12 : 0.97)
            GeometryReader { geometry in
                ZStack {
                    Ellipse().fill(colors[0].opacity(dark ? 0.23 : 0.16))
                        .frame(width: 550, height: 300)
                        .offset(x: drifting ? -120 : -230, y: drifting ? 270 : 230)
                    Ellipse().fill(colors[2].opacity(dark ? 0.21 : 0.16))
                        .frame(width: 510, height: 310)
                        .offset(x: drifting ? 340 : 240, y: drifting ? 250 : 330)
                    Ellipse().fill(colors[3].opacity(dark ? 0.14 : 0.18))
                        .frame(width: 380, height: 240)
                        .offset(x: 160, y: drifting ? 410 : 350)
                }
                .blur(radius: 65)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            }
            .accessibilityHidden(true)

            VStack(spacing: 0) {
                Spacer().frame(height: 72)
                HelloScript()
                    .trim(from: 0, to: reduceMotion ? 1 : ink)
                    .stroke(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                    .frame(width: 370, height: 176)
                    .accessibilityLabel("hello")
                    .padding(.bottom, 34)
                VStack(spacing: 10) {
                    Text("欢迎使用 Asky")
                        .font(.system(size: 27, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .opacity(arrived ? 1 : 0)
                .offset(y: arrived || reduceMotion ? 0 : 8)
                Spacer()
                Button(action: onStart) {
                    HStack(spacing: 10) {
                        Text("开始使用")
                        Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold))
                    }
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 25).frame(height: 42)
                    .background(dark ? Color.white : Color(red: 0.15, green: 0.15, blue: 0.18), in: Capsule())
                    .foregroundStyle(dark ? Color.black : Color.white)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("开始使用"))
                .keyboardShortcut(.defaultAction)
                .padding(.bottom, 42)
            }
        }
        .frame(width: 760, height: 520)
        .clipped()
        .task(id: reduceMotion) {
            ink = reduceMotion ? 1 : 0
            arrived = reduceMotion
            drifting = false
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.8)) { ink = 1 }
            withAnimation(.easeOut(duration: 0.65).delay(0.5)) { arrived = true }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { drifting = true }
        }
    }
}

/// A continuous, original monoline greeting; trimming follows the pen rather than a rectangular mask.
private struct HelloScript: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 18, y: 132))
        p.addCurve(to: CGPoint(x: 88, y: 24), control1: CGPoint(x: 58, y: 114), control2: CGPoint(x: 116, y: 4))
        p.addCurve(to: CGPoint(x: 52, y: 145), control1: CGPoint(x: 58, y: 40), control2: CGPoint(x: 57, y: 111))
        p.addCurve(to: CGPoint(x: 101, y: 102), control1: CGPoint(x: 75, y: 89), control2: CGPoint(x: 110, y: 80))
        p.addCurve(to: CGPoint(x: 121, y: 144), control1: CGPoint(x: 88, y: 144), control2: CGPoint(x: 90, y: 160))
        p.addCurve(to: CGPoint(x: 177, y: 103), control1: CGPoint(x: 173, y: 121), control2: CGPoint(x: 188, y: 81))
        p.addCurve(to: CGPoint(x: 144, y: 144), control1: CGPoint(x: 157, y: 78), control2: CGPoint(x: 121, y: 126))
        p.addCurve(to: CGPoint(x: 248, y: 27), control1: CGPoint(x: 184, y: 180), control2: CGPoint(x: 276, y: 35))
        p.addCurve(to: CGPoint(x: 211, y: 142), control1: CGPoint(x: 224, y: 18), control2: CGPoint(x: 192, y: 121))
        p.addCurve(to: CGPoint(x: 308, y: 26), control1: CGPoint(x: 239, y: 178), control2: CGPoint(x: 336, y: 32))
        p.addCurve(to: CGPoint(x: 276, y: 146), control1: CGPoint(x: 282, y: 14), control2: CGPoint(x: 250, y: 135))
        p.addCurve(to: CGPoint(x: 330, y: 106), control1: CGPoint(x: 299, y: 161), control2: CGPoint(x: 310, y: 109))
        p.addCurve(to: CGPoint(x: 342, y: 151), control1: CGPoint(x: 283, y: 111), control2: CGPoint(x: 310, y: 181))
        p.addCurve(to: CGPoint(x: 343, y: 105), control1: CGPoint(x: 366, y: 129), control2: CGPoint(x: 374, y: 91))
        p.addCurve(to: CGPoint(x: 392, y: 124), control1: CGPoint(x: 339, y: 126), control2: CGPoint(x: 366, y: 145))
        return p.applying(CGAffineTransform(scaleX: rect.width / 410, y: rect.height / 190)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }
}
