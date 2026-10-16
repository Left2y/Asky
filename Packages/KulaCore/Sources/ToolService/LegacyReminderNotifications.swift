import UserNotifications

/// One-way migration: retire Asky's former system notifications without requesting permission.
public enum LegacyReminderNotifications {
    public static func removeAll() async {
        let center = UNUserNotificationCenter.current()
        let categories: Set<String> = ["asky.reminder", "asky.preview"]
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.filter {
            categories.contains($0.content.categoryIdentifier)
        }.map(\.identifier))
        let delivered = await center.deliveredNotifications()
        center.removeDeliveredNotifications(withIdentifiers: delivered.filter {
            categories.contains($0.request.content.categoryIdentifier)
        }.map { $0.request.identifier })
    }
}
