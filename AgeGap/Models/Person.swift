import SwiftUI
import SwiftData
import Foundation

@Model
final class Person {
    // Default values are required for CloudKit sync compatibility —
    // CloudKit can deliver partial records and needs a safe fallback for every field.
    var id: UUID = UUID()
    var name: String = ""
    var birthday: Date = Date()
    var relationshipTag: String = "Other"
    var photoData: Data? = nil

    init(name: String, birthday: Date, relationshipTag: String, photoData: Data? = nil) {
        self.id = UUID()
        self.name = name
        self.birthday = birthday
        self.relationshipTag = relationshipTag
        self.photoData = photoData
    }

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
    }

    var nextBirthday: Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.month, .day], from: birthday)
        components.year = calendar.component(.year, from: now)
        var next = calendar.date(from: components)!
        if next <= calendar.startOfDay(for: now) {
            next = calendar.date(byAdding: .year, value: 1, to: next)!
        }
        return next
    }

    var daysUntilBirthday: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let nextBD = calendar.startOfDay(for: nextBirthday)
        return calendar.dateComponents([.day], from: today, to: nextBD).day ?? 0
    }

    var isBirthdayToday: Bool {
        let calendar = Calendar.current
        let now = Date()
        return calendar.component(.month, from: birthday) == calendar.component(.month, from: now) &&
               calendar.component(.day, from: birthday) == calendar.component(.day, from: now)
    }
}
