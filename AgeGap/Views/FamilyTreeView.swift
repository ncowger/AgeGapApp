import SwiftUI
import SwiftData

// MARK: - Generation Definition

private struct Generation {
    let title: String
    let tags: [String]
    let isMyGeneration: Bool

    static let all: [Generation] = [
        Generation(title: "Grandparents",          tags: ["Grandparent"],                               isMyGeneration: false),
        Generation(title: "Parents & Family",      tags: ["Parent", "Aunt/Uncle"],                      isMyGeneration: false),
        Generation(title: "My Generation",         tags: ["Me", "Spouse/Partner", "Sibling", "Cousin"], isMyGeneration: true),
        Generation(title: "Children's Generation", tags: ["Child", "Niece/Nephew"],                     isMyGeneration: false),
        Generation(title: "Grandchildren",         tags: ["Grandchild"],                                isMyGeneration: false),
    ]

    static let friends = Generation(title: "Friends & Others", tags: ["Friend", "Other"], isMyGeneration: false)
}

// MARK: - Main View

struct FamilyTreeView: View {
    @Query(sort: \Person.birthday) private var people: [Person]
    @State private var selectedPerson: Person?

    private func people(for generation: Generation) -> [Person] {
        people.filter { generation.tags.contains($0.relationshipTag) }
    }

    private var activeGenerations: [Generation] {
        Generation.all.filter { !people(for: $0).isEmpty }
    }

    private var friendPeople: [Person] {
        people(for: Generation.friends)
    }

    var body: some View {
        NavigationStack {
            Group {
                if people.isEmpty {
                    ContentUnavailableView(
                        "No People Yet",
                        systemImage: "figure.2.and.child.holdinghands",
                        description: Text("Add people in the People tab to build your family tree")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(activeGenerations.enumerated()), id: \.element.title) { index, generation in
                                GenerationRow(
                                    generation: generation,
                                    people: people(for: generation),
                                    isFirst: index == 0,
                                    isLast: index == activeGenerations.count - 1,
                                    onTap: { selectedPerson = $0 }
                                )
                            }

                            // Friends & Others shown below a divider if present
                            if !friendPeople.isEmpty {
                                Divider()
                                    .padding(.vertical, 16)
                                    .padding(.horizontal, 32)

                                GenerationRow(
                                    generation: Generation.friends,
                                    people: friendPeople,
                                    isFirst: true,
                                    isLast: true,
                                    onTap: { selectedPerson = $0 }
                                )
                            }
                        }
                        .padding(.vertical, 24)
                    }
                }
            }
            .navigationTitle("Family Tree")
            .sheet(item: $selectedPerson) { person in
                PersonDetailSheet(person: person)
            }
        }
    }
}

// MARK: - Generation Row

private struct GenerationRow: View {
    let generation: Generation
    let people: [Person]
    let isFirst: Bool
    let isLast: Bool
    let onTap: (Person) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Connector line coming down from above
            if !isFirst {
                Rectangle()
                    .fill(Color.gray.opacity(0.35))
                    .frame(width: 2, height: 24)
            }

            // Generation label
            Text(generation.title.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(generation.isMyGeneration ? Color.blue : Color.secondary)
                .tracking(1)
                .padding(.bottom, 10)
                .padding(.top, isFirst ? 0 : 6)

            // Person cards row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(people) { person in
                        TreePersonCard(person: person, highlighted: generation.isMyGeneration)
                            .onTapGesture { onTap(person) }
                    }
                }
                .padding(.horizontal, 24)
            }

            // Connector line going down to next row
            if !isLast {
                Rectangle()
                    .fill(Color.gray.opacity(0.35))
                    .frame(width: 2, height: 24)
            }
        }
    }
}

// MARK: - Tree Person Card

private struct TreePersonCard: View {
    let person: Person
    let highlighted: Bool

    var isMe: Bool { person.relationshipTag == "Me" }

    var body: some View {
        VStack(spacing: 6) {
            // Avatar
            ZStack {
                if let data = person.photoData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(colorForRelationship(person.relationshipTag))
                        .frame(width: avatarSize, height: avatarSize)
                        .overlay(
                            Text(person.name.prefix(2).uppercased())
                                .font(isMe ? .headline : .subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        )
                }

                // Star badge for "Me"
                if isMe {
                    VStack {
                        HStack {
                            Spacer()
                            Text("⭐️")
                                .font(.caption2)
                                .offset(x: 4, y: -4)
                        }
                        Spacer()
                    }
                    .frame(width: avatarSize, height: avatarSize)
                }
            }
            .overlay(
                Circle().stroke(
                    isMe ? Color.blue : (highlighted ? Color.blue.opacity(0.4) : Color.clear),
                    lineWidth: isMe ? 3 : 1.5
                )
            )
            .shadow(color: .black.opacity(0.1), radius: isMe ? 6 : 3)

            // Name
            Text(person.name.components(separatedBy: " ").first ?? person.name)
                .font(isMe ? .caption : .caption2)
                .fontWeight(isMe ? .bold : .regular)
                .foregroundStyle(isMe ? .blue : .primary)
                .lineLimit(1)

            // Age
            Text("Age \(person.age)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 72)
    }

    private var avatarSize: CGFloat { isMe ? 64 : 52 }
}

// MARK: - Person Detail Sheet

private struct PersonDetailSheet: View {
    let person: Person
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Avatar
                Group {
                    if let data = person.photoData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Circle()
                            .fill(colorForRelationship(person.relationshipTag))
                            .overlay(
                                Text(person.name.prefix(2).uppercased())
                                    .font(.largeTitle).bold()
                                    .foregroundStyle(.white)
                            )
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .shadow(radius: 6)

                VStack(spacing: 6) {
                    Text(person.name)
                        .font(.title2).bold()
                    Text("\(person.relationshipTag)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(colorForRelationship(person.relationshipTag).opacity(0.15))
                        .clipShape(Capsule())
                }

                VStack(spacing: 12) {
                    DetailRow(label: "Birthday", value: person.birthday.formatted(date: .long, time: .omitted))
                    DetailRow(label: "Age", value: "\(person.age) years old")
                    DetailRow(label: "Next Birthday", value: "in \(person.daysUntilBirthday) days")
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .padding(.top, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 8)
        .overlay(Divider(), alignment: .bottom)
    }
}
