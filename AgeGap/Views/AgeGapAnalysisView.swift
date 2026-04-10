import SwiftUI
import SwiftData

// MARK: - Age Pair model

struct AgePair: Identifiable {
    let id = UUID()
    let person1: Person
    let person2: Person

    private var comps: DateComponents {
        let earlier = person1.birthday <= person2.birthday ? person1.birthday : person2.birthday
        let later   = person1.birthday <= person2.birthday ? person2.birthday : person1.birthday
        return Calendar.current.dateComponents([.year, .month, .day], from: earlier, to: later)
    }

    var gapMonths: Int { (comps.year ?? 0) * 12 + (comps.month ?? 0) }

    var gapDescription: String {
        let y = comps.year  ?? 0
        let m = comps.month ?? 0
        let d = comps.day   ?? 0
        if y == 0 && m == 0 && d == 0 { return "Same day" }
        if y == 0 && m == 0 { return d == 1 ? "1 day"   : "\(d) days" }
        if y == 0            { return m == 1 ? "1 month" : "\(m) months" }
        if m == 0            { return y == 1 ? "1 year"  : "\(y) years" }
        return "\(y)y \(m)mo"
    }

    var older:   Person { person1.birthday <= person2.birthday ? person1 : person2 }
    var younger: Person { person1.birthday <= person2.birthday ? person2 : person1 }
}

// MARK: - View modes

private enum GapMode: String, CaseIterable {
    case compareToMe = "vs Me"
    case allPairs    = "All Pairs"
}

// MARK: - Main view

struct AgeGapAnalysisView: View {
    @Query(sort: \Person.birthday) private var people: [Person]
    @State private var mode: GapMode = .compareToMe
    @State private var showClosest = true

    private var me: Person? { people.first { $0.isMe } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(GapMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)

                switch mode {
                case .compareToMe: CompareMeView(me: me, people: people, showClosest: $showClosest)
                case .allPairs:    AllPairsView(people: people, showClosest: $showClosest)
                }
            }
            .navigationTitle("Age Gaps")
        }
    }
}

// MARK: - Compare to Me

private struct CompareMeView: View {
    let me: Person?
    let people: [Person]
    @Binding var showClosest: Bool

    private var others: [Person] {
        guard let me else { return [] }
        return people.filter { $0.id != me.id }
    }

    private var pairs: [AgePair] {
        guard let me else { return [] }
        return others
            .map { AgePair(person1: me, person2: $0) }
            .sorted { showClosest ? $0.gapMonths < $1.gapMonths : $0.gapMonths > $1.gapMonths }
    }

    var body: some View {
        Group {
            if me == nil {
                ContentUnavailableView(
                    "Add Yourself First",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("Mark one person as **Me** to use this view")
                )
            } else if others.isEmpty {
                ContentUnavailableView(
                    "Add More People",
                    systemImage: "person.2",
                    description: Text("Add at least one other person to compare gaps")
                )
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        GapStatCard(title: "Comparing to", value: me!.name.components(separatedBy: " ").first ?? "Me", accent: .blue)
                        GapStatCard(title: "Closest",  value: pairs.first?.gapDescription ?? "—", accent: .green)
                        GapStatCard(title: "Furthest", value: pairs.last?.gapDescription  ?? "—", accent: .red)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    Picker("Sort", selection: $showClosest) {
                        Text("Closest First").tag(true)
                        Text("Furthest First").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    List(pairs) { pair in
                        let other     = pair.older.id == me!.id ? pair.younger : pair.older
                        let direction = pair.older.id == me!.id ? "younger" : "older"
                        HStack(spacing: 12) {
                            VStack(spacing: 2) {
                                Text(pair.gapDescription)
                                    .font(.headline).bold()
                                    .foregroundStyle(.blue)
                                Text(direction)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 80)

                            Circle()
                                .fill(colorForPerson(other))
                                .frame(width: 10, height: 10)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(other.name).font(.subheadline).bold()
                                Text("Age \(other.age)")
                                    .font(.caption).foregroundStyle(.secondary)
                                if !other.notes.isEmpty {
                                    Text(other.notes)
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
}

// MARK: - All Pairs

private struct AllPairsView: View {
    let people: [Person]
    @Binding var showClosest: Bool

    private var pairs: [AgePair] {
        var result = [AgePair]()
        for i in 0..<people.count {
            for j in (i+1)..<people.count {
                result.append(AgePair(person1: people[i], person2: people[j]))
            }
        }
        return result.sorted { showClosest ? $0.gapMonths < $1.gapMonths : $0.gapMonths > $1.gapMonths }
    }

    var body: some View {
        Group {
            if pairs.isEmpty {
                ContentUnavailableView(
                    "Not Enough People",
                    systemImage: "person.2.slash",
                    description: Text("Add at least 2 people to compare age gaps")
                )
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        GapStatCard(title: "People",  value: "\(people.count)", accent: .blue)
                        GapStatCard(title: "Closest", value: pairs.first?.gapDescription ?? "—", accent: .green)
                        GapStatCard(title: "Furthest",value: pairs.last?.gapDescription  ?? "—", accent: .red)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    Picker("Sort", selection: $showClosest) {
                        Text("Closest First").tag(true)
                        Text("Furthest First").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    List(pairs) { pair in AgePairRow(pair: pair) }
                }
            }
        }
    }
}

// MARK: - Shared sub-views

struct GapStatCard: View {
    let title:  String
    let value:  String
    let accent: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline).bold()
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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
                personLine(pair.older,   label: "older")
                personLine(pair.younger, label: "younger")
            }
        }
        .padding(.vertical, 4)
    }

    private func personLine(_ person: Person, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(colorForPerson(person))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 0) {
                Text(person.name).font(.subheadline).bold()
                HStack(spacing: 4) {
                    Text("Age \(person.age)")
                    if !person.notes.isEmpty {
                        Text("· \(person.notes)").foregroundStyle(.tertiary)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
