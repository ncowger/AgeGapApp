import UserNotifications
import Foundation

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    func scheduleNotification(for person: Person) {
        let content = UNMutableNotificationContent()
        content.title = "🎂 Happy Birthday!"
        content.body = "Today is \(person.name)'s birthday — they're turning \(person.age + 1)!"
        content.sound = .default

        var components = Calendar.current.dateComponents([.month, .day], from: person.birthday)
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: notificationID(for: person),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelNotification(for person: Person) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationID(for: person)]
        )
    }

    private func notificationID(for person: Person) -> String {
        "birthday-\(person.id.uuidString)"
    }
}
