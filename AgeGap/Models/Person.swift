import SwiftUI
import SwiftData
import Foundation

@Model
final class Person {
    // Default values required for CloudKit sync compatibility
    var id: UUID = UUID()
    var name: String = ""
    var birthday: Date = Date()
    var relationshipTag: String = RelationshipTag.other.rawValue
    var photoData: Data? = nil
    var notes: String = ""        // free text e.g. "Emily's brother", "Dad's side"

    // Structured tree relationships (Option B)
    // spouseID: bidirectional — both partners store each other's ID
    // parentID: child → one parent (the blood/primary parent in this tree)
    //           the second parent is inferred via that parent's spouseID
    var spouseID: UUID? = nil
    var parentID: UUID? = nil

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

enum RelationshipTag: String, CaseIterable {
    case me           = "Me"
    case parent       = "Parent"
    case sibling      = "Sibling"
    case child        = "Child"
    case cousin       = "Cousin"
    case grandparent  = "Grandparent"
    case grandchild   = "Grandchild"
    case auntUncle    = "Aunt/Uncle"
    case nieceNephew  = "Niece/Nephew"
    case inLaw        = "In-Law"
    case stepFamily   = "Step-Family"
    case spousePartner = "Spouse/Partner"
    case friend       = "Friend"
    case other        = "Other"

    var emoji: String {
        switch self {
        case .me:            return "⭐️"
        case .parent:        return "👨‍👩‍👧"
        case .sibling:       return "👫"
        case .child:         return "🧒"
        case .cousin:        return "👥"
        case .grandparent:   return "👴"
        case .grandchild:    return "👶"
        case .auntUncle:     return "🧑‍🤝‍🧑"
        case .nieceNephew:   return "🧒"
        case .inLaw:         return "🤝"
        case .stepFamily:    return "👨‍👧"
        case .spousePartner: return "💑"
        case .friend:        return "🫂"
        case .other:         return "👤"
        }
    }

    var color: Color {
        switch self {
        case .me:            return .yellow
        case .parent:        return .blue
        case .sibling:       return .green
        case .child:         return .orange
        case .cousin:        return .purple
        case .grandparent:   return .brown
        case .grandchild:    return .indigo
        case .auntUncle:     return .cyan
        case .nieceNephew:   return .mint
        case .inLaw:         return .teal
        case .stepFamily:    return Color(red: 0.6, green: 0.4, blue: 0.8)
        case .spousePartner: return .pink
        case .friend:        return Color(red: 0.2, green: 0.7, blue: 0.5)
        case .other:         return .gray
        }
    }
}

func colorForRelationship(_ tag: String) -> Color {
    RelationshipTag(rawValue: tag)?.color ?? .gray
}
