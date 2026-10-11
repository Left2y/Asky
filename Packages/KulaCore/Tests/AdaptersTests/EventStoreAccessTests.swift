import Testing
@testable import Adapters

@Suite struct EventStoreAccessTests {
    @Test func settingsGrantInvalidatesStoreCreatedBeforeAuthorization() {
        var state = EventStoreAccessState()
        let resets = [
            state.observe(calendar: false, reminders: false),
            state.observe(calendar: true, reminders: false),
            state.observe(calendar: true, reminders: false),
            state.observe(calendar: true, reminders: true),
            state.observe(calendar: true, reminders: true),
        ]
        #expect(resets == [false, true, false, true, false])
    }

    @Test func revokeAndRegrantEachInvalidateSharedStore() {
        var state = EventStoreAccessState()
        let resets = [
            state.observe(calendar: true, reminders: true),
            state.observe(calendar: false, reminders: true),
            state.observe(calendar: true, reminders: true),
            state.observe(calendar: true, reminders: false),
            state.observe(calendar: true, reminders: true),
        ]
        #expect(resets == [false, true, true, true, true])
    }
}
