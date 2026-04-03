import SwiftUI
import SwiftData

@Model
final class Tag {
    // CloudKit-compatible: all fields have defaults
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = ""
    var colorName: String = "gray"
    var isBuiltIn: Bool = false
    var sortOrder: Int = 0

    init(name: String, emoji: String, colorName: String, isBuiltIn: Bool = false, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.colorName = colorName
        self.isBuiltIn = isBuiltIn
        self.sortOrder = sortOrder
    }

    var color: Color {
        TagColor(rawValue: colorName)?.color ?? .gray
    }

    // Seeded on first launch — mirrors the original RelationshipTag enum
    static let builtIns: [(name: String, emoji: String, colorName: String)] = [
        ("Me",             "⭐️",  "yellow"),
        ("Parent",         "👨‍👩‍👧", "blue"),
        ("Sibling",        "👫",  "green"),
        ("Child",          "🧒",  "orange"),
        ("Cousin",         "👥",  "purple"),
        ("Grandparent",    "👴",  "brown"),
        ("Grandchild",     "👶",  "indigo"),
        ("Aunt/Uncle",     "🧑‍🤝‍🧑", "cyan"),
        ("Niece/Nephew",   "🧒",  "mint"),
        ("Friend",         "🤝",  "teal"),
        ("Spouse/Partner", "💑",  "pink"),
        ("Other",          "👤",  "gray"),
    ]
}

// Fixed color palette for tag customisation
enum TagColor: String, CaseIterable {
    case yellow, blue, green, orange, purple, brown, indigo, cyan, mint, teal, pink, gray, red

    var color: Color {
        switch self {
        case .yellow: return .yellow
        case .blue:   return .blue
        case .green:  return .green
        case .orange: return .orange
        case .purple: return .purple
        case .brown:  return .brown
        case .indigo: return .indigo
        case .cyan:   return .cyan
        case .mint:   return .mint
        case .teal:   return .teal
        case .pink:   return .pink
        case .gray:   return .gray
        case .red:    return .red
        }
    }

    var displayName: String { rawValue.capitalized }
}

// Convenience helpers so views can call tags.color(for: person.relationshipTag)
extension [Tag] {
    func color(for tagName: String) -> Color {
        first { $0.name == tagName }?.color ?? .gray
    }

    func emoji(for tagName: String) -> String {
        first { $0.name == tagName }?.emoji ?? "👤"
    }
}
