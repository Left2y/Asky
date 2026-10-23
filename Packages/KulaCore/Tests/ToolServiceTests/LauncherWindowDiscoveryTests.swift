import ApplicationServices
import Testing
@testable import ToolService

struct LauncherWindowDiscoveryTests {
    @Test func unavailableCompatibilitySymbolsLeavePublicDiscoveryUsable() throws {
        let unavailable = LauncherWindowDiscovery.Runtime(createElement: nil, getWindow: nil)
        var cursor: UInt64 = 41
        let windows = try LauncherWindowDiscovery.recover(pid: 1, missing: [123], cursor: &cursor,
            deadline: .now.advanced(by: .seconds(1)), runtime: unavailable)
        #expect(windows.isEmpty)
        #expect(cursor == 41)
        #expect(LauncherWindowDiscovery.windowID(AXUIElementCreateApplication(1), runtime: unavailable) == nil)
    }

    @Test func expiredBudgetDoesNotSweepOrMoveCursor() throws {
        var cursor: UInt64 = 99
        let windows = try LauncherWindowDiscovery.recover(pid: 1, missing: [123], cursor: &cursor,
            deadline: .now.advanced(by: .seconds(-1)))
        #expect(windows.isEmpty)
        #expect(cursor == 99)
    }
}
