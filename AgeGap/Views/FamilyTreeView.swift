import SwiftUI
import SwiftData

// MARK: - Generation mapping

/// Assigns a vertical tier to each built-in tag.
/// Custom tags land on tier 0 (same row as "Me").
private let generationTier: [String: Int] = [
    "Grandparent":    -2,
    "Parent":         -1,
    "Aunt/Uncle":     -1,
    "Me":              0,
    "Spouse/Partner":  0,
    "Sibling":         0,
    "Cousin":          0,
    "Friend":          0,
    "Other":           0,
    "Child":           1,
    "Niece/Nephew":    1,
    "Grandchild":      2,
]

private let generationLabel: [Int: String] = [
    -2: "Grandparents",
    -1: "Parents & Aunts/Uncles",
     0: "My Generation",
     1: "Children & Nieces/Nephews",
     2: "Grandchildren",
]

// MARK: - View

struct FamilyTreeView: View {
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \Tag.sortOrder) private var tags: [Tag]

    /// Groups people by generation tier, sorted from oldest to youngest generation.
    private var generationGroups: [(tier: Int, label: String, people: [Person])] {
        var grouped: [Int: [Person]] = [:]
        for person in people {
            let tier = generationTier[person.relationshipTag] ?? 0
            grouped[tier, default: []].append(person)
        }
        return grouped
            .map { tier, members in
                let label = generationLabel[tier] ?? "Other"
                return (tier: tier, label: label, people: members.sorted { $0.name < $1.name })
            }
            .sorted { $0.tier < $1.tier }
    }

    var body: some View {
        NavigationStack {
            if people.isEmpty {
                ContentUnavailableView(
                    "No People Yet",
                    systemImage: "person.3",
                    description: Text("Add people in the People tab to build your family tree")
                )
                .navigationTitle("Family Tree")
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(generationGroups.enumerated()), id: \.element.tier) { index, group in
                            // Connector line from previous generation
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.35))
                                    .frame(width: 2, height: 28)
                            }

                            GenerationRowView(
                                label: group.label,
                                people: group.people,
                                tags: tags
                            )
                        }
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 16)
                }
                .navigationTitle("Family Tree")
            }
        }
    }
}

// MARK: - Generation row

struct GenerationRowView: View {
    let label: String
    let people: [Person]
    let tags: [Tag]

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .clipShape(Capsule())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(people) { person in
                        TreePersonCard(person: person, tags: tags)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// MARK: - Person card

struct TreePersonCard: View {
    let person: Person
    let tags: [Tag]

    var body: some View {
        VStack(spacing: 6) {
            avatar
            Text(person.name)
                .font(.caption).bold()
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 72)
            Text("Age \(person.age)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(tags.emoji(for: person.relationshipTag))
                .font(.caption2)
        }
        .frame(width: 80)
    }

    private var avatar: some View {
        Group {
            if let data = person.photoData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(person.name.prefix(2).uppercased())
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(tags.color(for: person.relationshipTag))
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
        .overlay(Circle().stroke(tags.color(for: person.relationshipTag).opacity(0.4), lineWidth: 2))
    }
}
