import UserNotifications
import Contracts

/// Explicit developer preview; does not create calendar items or scheduler records.
@MainActor
public enum NotificationPreview {
    public static func send() async throws {
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options: [.alert, .sound]) else {
            throw ToolError(.permissionDenied, "请在系统设置 › 通知 › Asky 中允许通知。")
        }
        var categories = await center.notificationCategories()
        categories.insert(UNNotificationCategory(identifier: "asky.preview", actions: [
            UNNotificationAction(identifier: "evidence", title: "查看依据", options: [.foreground]),
            UNNotificationAction(identifier: "handled", title: "已处理", options: []),
        ], intentIdentifiers: []))
        center.setNotificationCategories(categories)
        let content = UNMutableNotificationContent()
        content.title = "会议即将开始"
        content.body = "15 分钟后有产品讨论会，记得提前准备。\n这是一条测试通知，不会创建真实日程。"
        content.sound = .default
        content.categoryIdentifier = "asky.preview"
        content.userInfo = ["evidence": ["测试示例：产品讨论会将在 15 分钟后开始。"]]
        try await center.add(UNNotificationRequest(identifier: "asky.notification-preview", content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
    }
}
