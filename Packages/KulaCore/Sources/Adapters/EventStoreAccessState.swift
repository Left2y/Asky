/// Tracks both entity grants because a reset invalidates objects for the entire shared store.
struct EventStoreAccessState {
    private var last: [Bool]?

    mutating func observe(calendar: Bool, reminders: Bool) -> Bool {
        let current = [calendar, reminders]
        defer { last = current }
        guard let last else { return false }
        return last != current
    }
}
