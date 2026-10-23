import Foundation
import Testing
@testable import ToolService

struct LauncherWindowDisplayLayoutTests {
    @Test func horizontalOrderAndWrapIgnorePrimaryDisplayOrder() {
        let screens = [CGRect(x: 0, y: 0, width: 1200, height: 900),
                       CGRect(x: -1200, y: 20, width: 1200, height: 900),
                       CGRect(x: 1200, y: 0, width: 1200, height: 900)]
        let window = CGRect(x: 100, y: 100, width: 600, height: 400)
        #expect(LauncherWindowDisplayLayout.target(for: window, displays: screens, direction: -1) == 1)
        #expect(LauncherWindowDisplayLayout.target(for: window, displays: screens, direction: 1) == 2)
        #expect(LauncherWindowDisplayLayout.target(for: screens[2], displays: screens, direction: 1) == 1)
        #expect(LauncherWindowDisplayLayout.target(for: screens[1], displays: screens, direction: -1) == 2)
    }

    @Test func verticalOrderUsesTopAsPreviousEvenWithHorizontalOffsets() {
        let screens = [CGRect(x: 0, y: 0, width: 1200, height: 900),
                       CGRect(x: 100, y: -900, width: 1200, height: 900),
                       CGRect(x: -100, y: 900, width: 1200, height: 900)]
        let window = CGRect(x: 100, y: 100, width: 600, height: 400)
        #expect(LauncherWindowDisplayLayout.target(for: window, displays: screens, direction: -1) == 1)
        #expect(LauncherWindowDisplayLayout.target(for: window, displays: screens, direction: 1) == 2)
        #expect(LauncherWindowDisplayLayout.target(for: window, displays: [screens[0]], direction: 1) == nil)
        #expect(LauncherWindowDisplayLayout.target(for: window, displays: [], direction: -1) == nil)
    }

    @Test func spanningAndOffscreenWindowsResolveTheirOwnDisplay() {
        let screens = [CGRect(x: 0, y: 0, width: 1200, height: 900),
                       CGRect(x: 1200, y: 0, width: 1200, height: 900)]
        #expect(LauncherWindowDisplayLayout.source(for: CGRect(x: 1100, y: 50, width: 800, height: 500), displays: screens) == 1)
        #expect(LauncherWindowDisplayLayout.source(for: CGRect(x: -500, y: 50, width: 100, height: 100), displays: screens) == 0)
    }

    @Test func retainsRelativePositionAndFitsSmallerWorkArea() {
        let source = CGRect(x: 0, y: 25, width: 1200, height: 875)
        let target = CGRect(x: -800, y: -600, width: 800, height: 575)
        let frame = LauncherWindowDisplayLayout.frame(for: CGRect(x: 300, y: 262.5, width: 600, height: 400), source: source, destination: target)
        #expect(frame == CGRect(x: -700, y: -512.5, width: 600, height: 400))
        let oversized = LauncherWindowDisplayLayout.frame(for: source, source: source, destination: target)
        #expect(oversized == target)
    }
}
