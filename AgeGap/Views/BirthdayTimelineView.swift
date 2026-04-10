import SwiftUI
import SwiftData

struct BirthdayTimelineView: View {
    @Query(sort: \Person.birthday) private var people: [Person]
    @State private var selectedPeople: [Person] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if people.isEmpty {
                    ContentUnavailableView(
                        "No People",
                        systemImage: "person.slash",
                        description: Text("Add people to see the timeline")
                    )
                } else {
                    ZStack(alignment: .bottom) {
                        ScrollView {
                            TimelineContent(
                                people: people,
                                selectedPeople: $selectedPeople
                            )
                            .padding()
                            .padding(.bottom, selectedPeople.count == 2 ? 130 : 0)
                        }

                        if selectedPeople.count == 2 {
                            GapComparisonCard(
                                person1: selectedPeople[0],
                                person2: selectedPeople[1],
                                onDismiss: { selectedPeople = [] }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.35), value: selectedPeople.count)
                }
            }
            .navigationTitle("Timeline")
            .toolbar {
                if !selectedPeople.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear") { selectedPeople = [] }
                            .font(.subheadline)
                    }
                }
            }
        }
    }
}

// MARK: - Timeline Content

struct TimelineContent: View {
    let people: [Person]
    @Binding var selectedPeople: [Person]

    var sorted: [Person] { people.sorted { $0.birthday < $1.birthday } }

    var body: some View {
        VStack(spacing: 0) {
            if selectedPeople.isEmpty {
                Text("Tap two people to compare their age gap")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            } else if selectedPeople.count == 1 {
                Text("Now tap a second person")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.bottom, 12)
            }

            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, person in
                let isSelected = selectedPeople.contains { $0.id == person.id }
                let selectionIndex = selectedPeople.firstIndex { $0.id == person.id }

                HStack(alignment: .center, spacing: 16) {
                    Text(String(Calendar.current.component(.year, from: person.birthday)))
                        .font(.caption)
                        .foregroundStyle(isSelected ? .blue : .secondary)
                        .monospacedDigit()
                        .fontWeight(isSelected ? .bold : .regular)
                        .frame(width: 44, alignment: .trailing)

                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 2, height: index == 0 ? 16 : 28)

                        ZStack {
                            Circle()
                                .fill(colorForPerson(person))
                                .frame(width: isSelected ? 22 : 14, height: isSelected ? 22 : 14)
                                .overlay(
                                    Circle().stroke(
                                        isSelected ? Color.blue : Color(.systemBackground),
                                        lineWidth: isSelected ? 3 : 2
                                    )
                                )
                                .shadow(radius: isSelected ? 4 : 2)

                            if let idx = selectionIndex {
                                Text("\(idx + 1)")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(.white)
                            }
                        }
                        .animation(.spring(response: 0.25), value: isSelected)

                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 2, height: index == sorted.count - 1 ? 16 : 28)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.name)
                            .font(.subheadline).bold()
                            .foregroundStyle(isSelected ? .blue : .primary)
                        HStack(spacing: 4) {
                            Text("Age \(person.age)")
                            if !person.notes.isEmpty {
                                Text("• \(person.notes)").lineLimit(1)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Text(person.birthday.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.title3)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { handleTap(person) }

                if index < sorted.count - 1 {
                    let gapText = preciseGap(from: person.birthday, to: sorted[index + 1].birthday)
                    HStack(spacing: 16) {
                        Spacer().frame(width: 44)
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 2, height: 10)
                        Text(gapText)
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

    private func preciseGap(from d1: Date, to d2: Date) -> String {
        let earlier = min(d1, d2)
        let later   = max(d1, d2)
        let c = Calendar.current.dateComponents([.year, .month, .day], from: earlier, to: later)
        let y = c.year  ?? 0
        let m = c.month ?? 0
        let d = c.day   ?? 0
        if y == 0 && m == 0 && d == 0 { return "Same day" }
        if y == 0 && m == 0 { return "\(d)d gap" }
        if y == 0 { return m == 1 ? "1 mo gap" : "\(m) mo gap" }
        if m == 0 { return y == 1 ? "1 yr gap" : "\(y) yr gap" }
        return "\(y)y \(m)mo gap"
    }

    private func handleTap(_ person: Person) {
        if let idx = selectedPeople.firstIndex(where: { $0.id == person.id }) {
            selectedPeople.remove(at: idx)
        } else if selectedPeople.count < 2 {
            selectedPeople.append(person)
        } else {
            selectedPeople = [selectedPeople[1], person]
        }
    }

    private func yearGap(from p1: Person, to p2: Person) -> Int {
        let c = Calendar.current
        return abs(c.component(.year, from: p1.birthday) - c.component(.year, from: p2.birthday))
    }
}

// MARK: - Gap Comparison Card

struct GapComparisonCard: View {
    let person1: Person
    let person2: Person
    let onDismiss: () -> Void

    private var older:   Person { person1.birthday <= person2.birthday ? person1 : person2 }
    private var younger: Person { person1.birthday <= person2.birthday ? person2 : person1 }

    private var gapDescription: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: older.birthday, to: younger.birthday)
        let y = c.year ?? 0
        let m = c.month ?? 0
        let d = c.day ?? 0
        if y == 0 && m == 0 && d == 0 { return "Same birthday!" }
        if y == 0 && m == 0 { return "\(d) day\(d == 1 ? "" : "s") apart" }
        if y == 0 { return "\(m) month\(m == 1 ? "" : "s") apart" }
        if m == 0 { return "\(y) year\(y == 1 ? "" : "s") apart" }
        return d > 0 ? "\(y)y \(m)mo \(d)d apart" : "\(y)y \(m)mo apart"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Age Gap")
                    .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary).font(.title3)
                }
            }

            Text(gapDescription)
                .font(.title2).bold().foregroundStyle(.blue)

            HStack(spacing: 0) {
                personChip(older,   label: "older")
                Image(systemName: "arrow.right")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
                personChip(younger, label: "younger")
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 12, y: -4)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func personChip(_ person: Person, label: String) -> some View {
        VStack(spacing: 3) {
            Text(person.name).font(.subheadline).bold()
            Text("Age \(person.age)").font(.caption).foregroundStyle(.secondary)
            Text(label).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(colorForPerson(person).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
