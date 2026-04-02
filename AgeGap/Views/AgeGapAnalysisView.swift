import SwiftUI
import SwiftData

struct AgePair: Identifiable {
    let id = UUID()
    let person1: Person
    let person2: Person

    private var components: DateComponents {
        let earlier = person1.birthday < person2.birthday ? person1.birthday : person2.birthday
        let later   = person1.birthday < person2.birthday ? person2.birthday : person1.birthday
        return Calendar.current.dateComponents([.year, .month, .day], from: earlier, to: later)
    }

    var gapYears: Int { components.year ?? 0 }
    var gapMonths: Int { (components.year ?? 0) * 12 + (components.month ?? 0) }

    var gapDescription: String {
        let y = components.year ?? 0
        let m = components.month ?? 0
        let d = components.day ?? 0
        if y == 0 && m == 0 && d == 0 { return "same day" }
        if y == 0 && m == 0 { return "\(d)d" }
        if y == 0 { return "\(m)mo" }
        if m == 0 { return "\(y)y" }
        return "\(y)y \(m)mo"
    }

    var older:   Person { person1.birthday <= person2.birthday ? person1 : person2 }
    var younger: Person { person1.birthday <= person2.birthday ? person2 : person1 }
}

struct AgeGapAnalysisView: View {
    @Query(sort: \Person.birthday) private var people: [Person]
    @State private var selectedTag = "All"
    @State private var showClosest = true

    var allTags: [String] {
        ["All"] + RelationshipTag.allCases.map(\.rawValue)
    }

    var filteredPeople: [Person] {
        selectedTag == "All" ? people : people.filter { $0.relationshipTag == selectedTag }
    }

    var pairs: [AgePair] {
        let fp = filteredPeople
        var result: [AgePair] = []
        for i in 0..<fp.count {
            for j in (i + 1)..<fp.count {
                result.append(AgePair(person1: fp[i], person2: fp[j]))
            }
        }
        return result.sorted { showClosest ? $0.gapMonths < $1.gapMonths : $0.gapMonths > $1.gapMonths }
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

                if !pairs.isEmpty {
                    HStack(spacing: 12) {
                        GapStatCard(title: "People", value: "\(filteredPeople.count)", accent: .blue)
                        GapStatCard(title: "Closest Gap", value: pairs.first?.gapDescription ?? "—", accent: .green)
                        GapStatCard(title: "Biggest Gap", value: pairs.last?.gapDescription ?? "—", accent: .red)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                Picker("Sort", selection: $showClosest) {
                    Text("Closest First").tag(true)
                    Text("Furthest First").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                if pairs.isEmpty {
                    ContentUnavailableView(
                        "Not Enough People",
                        systemImage: "person.2.slash",
                        description: Text("Add at least 2 people to compare age gaps")
                    )
                } else {
                    List(pairs) { pair in
                        AgePairRow(pair: pair)
                    }
                }
            }
            .navigationTitle("Age Gaps")
        }
    }
}

struct GapStatCard: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline).bold()
                .foregroundStyle(accent)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct AgePairRow: View {
    let pair: AgePair

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(pair.gapDescription)
                    .font(.headline).bold()
                    .foregroundStyle(.blue)
                Text("apart")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 72)

            VStack(alignment: .leading, spacing: 6) {
                personLine(pair.older, label: "older")
                personLine(pair.younger, label: "younger")
            }
        }
        .padding(.vertical, 4)
    }

    private func personLine(_ person: Person, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(colorForRelationship(person.relationshipTag))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 0) {
                Text(person.name).font(.subheadline).bold()
                Text("\(person.relationshipTag) • Age \(person.age)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
