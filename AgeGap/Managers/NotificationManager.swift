import UserNotifications
import Foundation

// MARK: - Settings keys (shared with SettingsView via @AppStorage)
enum ReminderKey {
    static let enabled     = "rem_enabled"
    static let bdayEnabled = "rem_bdayEnabled"   // single birthday reminder on/off
    static let bdayDays    = "rem_bdayDays"       // 0 = on birthday, >0 = days in advance
    static let monthly     = "rem_monthly"
}

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    // MARK: - Reschedule everything

    /// Cancels ALL pending notifications and rebuilds from scratch based on
    /// current settings and the full people list. Call this whenever people
    /// change or settings change.
    func rescheduleAll(people: [Person]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let d = UserDefaults.standard
        let enabled     = d.object(forKey: ReminderKey.enabled)     == nil ? true  : d.bool(forKey: ReminderKey.enabled)
        guard enabled else { return }

        let bdayEnabled = d.object(forKey: ReminderKey.bdayEnabled) == nil ? true  : d.bool(forKey: ReminderKey.bdayEnabled)
        let bdayDays    = d.object(forKey: ReminderKey.bdayDays)    == nil ? 0     : d.integer(forKey: ReminderKey.bdayDays)
        let monthly     = d.object(forKey: ReminderKey.monthly)     == nil ? false : d.bool(forKey: ReminderKey.monthly)

        if bdayEnabled {
            for person in people {
                scheduleBirthday(person: person, daysBefore: bdayDays)
            }
        }

        if monthly {
            scheduleMonthlyReminders(people: people)
        }
    }

    // MARK: - Per-person birthday notification (repeats annually)

    private func scheduleBirthday(person: Person, daysBefore: Int) {
        let calendar = Calendar.current

        // Compute the month/day the notification should fire
        guard let notifDate = calendar.date(byAdding: .day, value: -daysBefore,
                                            to: person.birthday) else { return }

        var trigger        = calendar.dateComponents([.month, .day], from: notifDate)
        trigger.hour       = 9
        trigger.minute     = 0
        trigger.second     = 0

        let content    = UNMutableNotificationContent()
        content.sound  = .default
        let turningAge = person.age + 1

        switch daysBefore {
        case 0:
            content.title = "🎂 Happy Birthday!"
            content.body  = "Today is \(person.name)'s birthday — they're turning \(turningAge)!"
        case 1:
            content.title = "🎂 Birthday Tomorrow!"
            content.body  = "\(person.name) turns \(turningAge) tomorrow. Don't forget!"
        case 2...6:
            content.title = "🎂 Upcoming Birthday"
            content.body  = "\(person.name)'s birthday is in \(daysBefore) days — they'll be \(turningAge)."
        default:
            let weeks   = daysBefore / 7
            let extra   = daysBefore % 7
            let timeStr = extra == 0
                ? "\(weeks) week\(weeks == 1 ? "" : "s")"
                : "\(daysBefore) days"
            content.title = "🎂 Upcoming Birthday"
            content.body  = "\(person.name)'s birthday is in \(timeStr) — they'll be \(turningAge)."
        }

        let notifTrigger = UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
        let id  = "bday-\(person.id.uuidString)-\(daysBefore)"
        let req = UNNotificationRequest(identifier: id, content: content, trigger: notifTrigger)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - Monthly "birthdays this month" (fires 9am on 1st of each month)

    private func scheduleMonthlyReminders(people: [Person]) {
        let calendar = Calendar.current

        for month in 1...12 {
            let birthdays = people
                .filter { calendar.component(.month, from: $0.birthday) == month }
                .sorted { calendar.component(.day, from: $0.birthday) <
                           calendar.component(.day, from: $1.birthday) }

            guard !birthdays.isEmpty else { continue }

            let nameList = birthdays.map { p in
                "\(p.name) (\(ordinal(calendar.component(.day, from: p.birthday))))"
            }.joined(separator: " · ")

            let content       = UNMutableNotificationContent()
            content.title     = "🗓 Birthdays This Month"
            content.body      = nameList
            content.sound     = .default

            var trigger        = DateComponents()
            trigger.month      = month
            trigger.day        = 1
            trigger.hour       = 9
            trigger.minute     = 0

            let notifTrigger = UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
            let id  = "monthly-\(month)"
            let req = UNNotificationRequest(identifier: id, content: content, trigger: notifTrigger)
            UNUserNotificationCenter.current().add(req)
        }
    }

    // MARK: - Helpers

    private func ordinal(_ n: Int) -> String {
        switch n % 10 {
        case 1 where n % 100 != 11: return "\(n)st"
        case 2 where n % 100 != 12: return "\(n)nd"
        case 3 where n % 100 != 13: return "\(n)rd"
        default:                     return "\(n)th"
        }
    }
}
