import UserNotifications
import Foundation

// MARK: - Settings keys (shared with SettingsView via @AppStorage)
enum ReminderKey {
    static let enabled  = "rem_enabled"
    static let dayOf    = "rem_dayOf"
    static let adv1     = "rem_adv1"
    static let adv1Days = "rem_adv1Days"
    static let adv2     = "rem_adv2"
    static let adv2Days = "rem_adv2Days"
    static let monthly  = "rem_monthly"
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
        let enabled  = d.object(forKey: ReminderKey.enabled)  == nil ? true  : d.bool(forKey: ReminderKey.enabled)

        // If reminders are globally off, leave everything cleared and return
        guard enabled else { return }

        let dayOf    = d.object(forKey: ReminderKey.dayOf)    == nil ? true  : d.bool(forKey: ReminderKey.dayOf)
        let adv1     = d.object(forKey: ReminderKey.adv1)     == nil ? false : d.bool(forKey: ReminderKey.adv1)
        let adv1Days = d.object(forKey: ReminderKey.adv1Days) == nil ? 7     : d.integer(forKey: ReminderKey.adv1Days)
        let adv2     = d.object(forKey: ReminderKey.adv2)     == nil ? false : d.bool(forKey: ReminderKey.adv2)
        let adv2Days = d.object(forKey: ReminderKey.adv2Days) == nil ? 1     : d.integer(forKey: ReminderKey.adv2Days)
        let monthly  = d.object(forKey: ReminderKey.monthly)  == nil ? false : d.bool(forKey: ReminderKey.monthly)

        for person in people {
            if dayOf {
                scheduleBirthday(person: person, daysBefore: 0)
            }
            if adv1 && adv1Days > 0 {
                scheduleBirthday(person: person, daysBefore: adv1Days)
            }
            if adv2 && adv2Days > 0 && adv2Days != adv1Days {
                scheduleBirthday(person: person, daysBefore: adv2Days)
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

        var trigger = calendar.dateComponents([.month, .day], from: notifDate)
        trigger.hour   = 9
        trigger.minute = 0
        trigger.second = 0

        let content        = UNMutableNotificationContent()
        content.sound      = .default
        let turningAge     = person.age + 1

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
            let weeks = daysBefore / 7
            let extra = daysBefore % 7
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
