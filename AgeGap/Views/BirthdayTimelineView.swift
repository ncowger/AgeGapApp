import SwiftUI
import SwiftData

struct BirthdayTimelineView: View {
    @Query(sort: \Person.birthday) private var people: [Person]
    @State private var selectedTag = "All"

    var allTags: [String] {
        ["All"] + RelationshipTag.allCases.map(\.rawValue)
    }

    var filteredPeople: [Person] {
        selectedTag == "All" ? people : people.filter { $0.relationshipTag == selectedTag }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allTags, id: \.self) { tag in
                            Button(tag) { selectedTag = tag }
                                .buttonStyle(.bordered)
                                .tint(selectedTag == tag ? .blue : .gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                if filteredPeople.isEmpty {
                    ContentUnavailableView(
                        "No People",
                        systemImage: "person.slash",
                        description: Text("Add people to see the timeline")
                    )
                } else {
                    ScrollView {
                        TimelineContent(people: filteredPeople)
                            .padding()
                    }
                }
            }
            .navigationTitle("Timeline")
        }
    }
}

struct TimelineContent: View {
    let people: [Person]

    var sorted: [Person] { people.sorted { $0.birthday < $1.birthday } }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, person in
                HStack(alignment: .center, spacing: 16) {
                    // Year label
                    Text(String(Calendar.current.component(.year, from: person.birthday)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)

                    // Line + dot
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 2, height: index == 0 ? 16 : 28)
                        Circle()
                            .fill(colorForRelationship(person.relationshipTag))
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 2)
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 2, height: index == sorted.count - 1 ? 16 : 28)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.name).font(.subheadline).bold()
                        HStack(spacing: 4) {
                            Text(person.relationshipTag)
                            Text("• Age \(person.age)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Text(person.birthday.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()
                }

                // Gap badge between consecutive entries
                if index < sorted.count - 1 {
                    let gap = yearGap(from: person, to: sorted[index + 1])
                    HStack(spacing: 16) {
                        Spacer().frame(width: 44)
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 2, height: 10)
                        Text(gap == 0 ? "< 1y apart" : "\(gap)y gap")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                        Spacer()
                    }
                }
            }
        }
    }

    private func yearGap(from p1: Person, to p2: Person) -> Int {
        let c = Calendar.current
        return abs(c.component(.year, from: p1.birthday) - c.component(.year, from: p2.birthday))
    }
}
