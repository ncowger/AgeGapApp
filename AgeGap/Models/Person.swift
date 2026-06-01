import SwiftUI
import SwiftData
import Foundation

@Model
final class Person {
    var id: UUID = UUID()
    var name: String = ""
    var birthday: Date = Date()
    var isMe: Bool = false
    var photoData: Data? = nil
    var notes: String = ""

    // Structured tree relationships
    var spouseID:  UUID? = nil
    var parent1ID: UUID? = nil   // primary / biological parent 1
    var parent2ID: UUID? = nil   // primary / biological parent 2

    init(name: String, birthday: Date, isMe: Bool = false, photoData: Data? = nil) {
        self.id = UUID()
        self.name = name
        self.birthday = birthday
        self.isMe = isMe
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

/// Consistent color per person, derived from their UUID. "Me" is always blue.
/// Uses UUID bytes rather than String.hash so the color is stable across process launches.
func colorForPerson(_ person: Person) -> Color {
    if person.isMe { return .blue }
    let palette: [Color] = [.purple, .orange, .pink, .teal, .indigo, .green, .cyan, .mint, .brown]
    let index = Int(person.id.uuid.0) % palette.count
    return palette[index]
}
