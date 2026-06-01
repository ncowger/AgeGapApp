import SwiftUI
import SwiftData

struct BirthdayTimelineView: View {
    @Query(sort: \Person.birthday) private var people: [Person]
    @State private var selectedPeople: [Person] = []

    var body: some View {
        NavigationStack {
            // Wrap in ZStack so NavigationStack sees a normal view as its direct
            // child — bare GeometryReader collapses the large navigation title.
            ZStack {
             GeometryReader { geo in
                if people.isEmpty {
                    ContentUnavailableView(
                        "No People",
                        systemImage: "person.slash",
                        description: Text("Add people to see the timeline")
                    )
                } else if geo.size.width > geo.size.height {
                    // ── Landscape: horizontal history timeline ──
                    HorizontalTimelineView(
                        people: Array(people),
                        selectedPeople: $selectedPeople
                    )
                } else {
                    // ── Portrait: vertical list ──
                    ZStack(alignment: .bottom) {
                        ScrollView {
                            TimelineContent(
                                people: Array(people),
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
             } // GeometryReader
            } // ZStack
            .navigationTitle("Timeline")
            .toolbar {
                if !selectedPeople.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") { selectedPeople = [] }
                            .font(.subheadline)
                    }
                }
            }
        }
    }
}

// MARK: - Horizontal Timeline (Landscape)

private struct HorizontalTimelineView: View {
    let people: [Person]
    @Binding var selectedPeople: [Person]

    // Layout constants
    private let pxPerYear:  CGFloat = 72
    private let hPad:       CGFloat = 64
    private let nodeSize:   CGFloat = 44
    // Three stem heights for staggering — round-robin by sorted index
    private let stemTiers:  [CGFloat] = [58, 90, 122]

    private var cal: Calendar { .current }

    private var sorted: [Person] { people.sorted { $0.birthday < $1.birthday } }

    // ── Year helpers ──────────────────────────────────────────────────────

    private func year(_ p: Person) -> Int {
        cal.component(.year, from: p.birthday)
    }

    /// X position with sub-year precision (uses month for finer placement)
    private func xPos(_ person: Person) -> CGFloat {
        let y = Double(year(person))
        let m = Double(cal.component(.month, from: person.birthday))
        return hPad + CGFloat(y - Double(startDecade) + (m - 1) / 12.0) * pxPerYear
    }

    private func xPos(_ absoluteYear: Int) -> CGFloat {
        hPad + CGFloat(absoluteYear - startDecade) * pxPerYear
    }

    private var startDecade: Int {
        let y = sorted.first.map { year($0) } ?? 1970
        return (y / 10) * 10 - 10
    }

    private var endDecade: Int {
        let y = sorted.last.map { year($0) } ?? 2020
        return ((y / 10) + 2) * 10
    }

    private var decades: [Int] { Array(stride(from: startDecade, through: endDecade, by: 10)) }

    private var totalWidth: CGFloat { xPos(endDecade) + hPad }

    // ── Stagger helpers ───────────────────────────────────────────────────

    private func stemHeight(for idx: Int) -> CGFloat { stemTiers[idx % stemTiers.count] }

    // ── Selection helpers ────────────────────────────────────────────────

    private func isSelected(_ p: Person) -> Bool {
        selectedPeople.contains { $0.id == p.id }
    }

    private func handleTap(_ person: Person) {
        withAnimation(.spring(response: 0.25)) {
            if let i = selectedPeople.firstIndex(where: { $0.id == person.id }) {
                selectedPeople.remove(at: i)
            } else if selectedPeople.count < 2 {
                selectedPeople.append(person)
            } else {
                selectedPeople = [selectedPeople[1], person]
            }
        }
    }

    // ── Body ──────────────────────────────────────────────────────────────

    var body: some View {
        GeometryReader { geo in
            // Axis sits 62% down so nodes have room above and decade labels below
            let axisY = geo.size.height * 0.62

            ZStack(alignment: .bottom) {

                // ── Scrollable canvas ──────────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {

                        // Alternating decade band shading
                        ForEach(Array(decades.enumerated()), id: \.offset) { idx, decade in
                            if idx % 2 == 0 && decade < endDecade {
                                Rectangle()
                                    .fill(Color.primary.opacity(0.028))
                                    .frame(width: pxPerYear * 10, height: geo.size.height)
                                    .offset(x: xPos(decade))
                            }
                        }

                        // Axis line, decade ticks, person ticks + stems
                        Canvas { ctx, size in

                            // Main axis
                            var axis = Path()
                            axis.move(to: .init(x: 0, y: axisY))
                            axis.addLine(to: .init(x: size.width, y: axisY))
                            ctx.stroke(axis,
                                       with: .color(.secondary.opacity(0.4)),
                                       style: StrokeStyle(lineWidth: 2))

                            // Decade ticks (tall, prominent)
                            for decade in decades {
                                let xd = xPos(decade)
                                var t = Path()
                                t.move(to: .init(x: xd, y: axisY - 30))
                                t.addLine(to: .init(x: xd, y: axisY + 18))
                                ctx.stroke(t,
                                           with: .color(.secondary.opacity(0.5)),
                                           style: StrokeStyle(lineWidth: 2))
                            }

                            // Per-person: axis dot + dashed stem
                            for (idx, person) in sorted.enumerated() {
                                let px  = xPos(person)
                                let sel = isSelected(person)
                                let sh  = stemHeight(for: idx)
                                let circleTop = axisY - sh - nodeSize / 2

                                // Small dot at axis
                                let dotR: CGFloat = 3.5
                                let dot = Path(ellipseIn: CGRect(x: px - dotR, y: axisY - dotR,
                                                                  width: dotR * 2, height: dotR * 2))
                                ctx.fill(dot, with: .color(sel ? Color.orange : Color.secondary.opacity(0.55)))

                                // Dashed stem from dot to circle bottom
                                var stem = Path()
                                stem.move(to: .init(x: px, y: axisY - dotR * 2))
                                stem.addLine(to: .init(x: px, y: circleTop + nodeSize + 2))
                                ctx.stroke(stem,
                                           with: .color(sel ? Color.orange.opacity(0.55) : Color.secondary.opacity(0.28)),
                                           style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                            }
                        }
                        .frame(width: totalWidth, height: geo.size.height)

                        // Decade labels — centred within each decade span, below axis
                        ForEach(Array(decades.dropLast().enumerated()), id: \.offset) { _, decade in
                            let midX = xPos(decade) + pxPerYear * 5
                            VStack(spacing: 2) {
                                Text(String(decade))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary.opacity(0.55))
                                Text("— \(decade + 9)")
                                    .font(.system(size: 9, weight: .regular, design: .rounded))
                                    .foregroundStyle(.secondary.opacity(0.35))
                            }
                            .position(x: midX, y: axisY + 34)
                        }

                        // Person nodes — all above the axis, staggered heights
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, person in
                            let px       = xPos(person)
                            let sh       = stemHeight(for: idx)
                            let circleY  = axisY - sh
                            let sel      = isSelected(person)

                            VStack(spacing: 4) {
                                // Name above circle
                                Text(person.name.components(separatedBy: " ").first ?? person.name)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(sel ? .orange : .primary)
                                    .lineLimit(1)
                                    .frame(maxWidth: nodeSize + 24)

                                // Circle
                                ZStack {
                                    if sel {
                                        Circle()
                                            .fill(Color.orange.opacity(0.2))
                                            .frame(width: nodeSize + 10, height: nodeSize + 10)
                                    }
                                    if let data = person.photoData, let img = UIImage(data: data) {
                                        Image(uiImage: img)
                                            .resizable().scaledToFill()
                                            .frame(width: nodeSize, height: nodeSize)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(colorForPerson(person))
                                            .frame(width: nodeSize, height: nodeSize)
                                            .overlay(
                                                Text(person.name.prefix(2).uppercased())
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(.white)
                                            )
                                    }
                                }
                                .overlay(
                                    Circle()
                                        .stroke(sel ? Color.orange : Color(.systemBackground),
                                                lineWidth: sel ? 2.5 : 1.5)
                                        .frame(width: nodeSize, height: nodeSize)
                                )
                                .shadow(color: sel ? .orange.opacity(0.45) : .black.opacity(0.12),
                                        radius: sel ? 7 : 3)

                                // Birth year below circle (closest to axis)
                                Text(String(year(person)))
                                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                                    .foregroundStyle(sel ? .orange.opacity(0.85) : .secondary.opacity(0.7))
                            }
                            .position(x: px, y: circleY)
                            .onTapGesture { handleTap(person) }
                        }
                    }
                    .frame(width: totalWidth, height: geo.size.height)
                }
                // Subtle edge-fade so content clearly scrolls
                .mask(
                    HStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: 28)
                        Color.black
                        LinearGradient(colors: [.black, .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: 28)
                    }
                )

                // ── Hint pill ─────────────────────────────────────────
                if selectedPeople.count < 2 {
                    Label(
                        selectedPeople.count == 1 ? "Tap one more to compare" : "Tap two people to compare",
                        systemImage: selectedPeople.count == 1 ? "hand.tap" : "hand.point.up.left"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 10)
                }

                // ── Comparison card ───────────────────────────────────
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
}

// MARK: - Portrait Timeline Content

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
                    let gapText = preciseGap(from: person.birthday,
                                            to: sorted[index + 1].birthday)
                    HStack(spacing: 16) {
                        Spacer().frame(width: 44)
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 2, height: 10)
                        Text(gapText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                        Spacer()
                    }
                }
            }
        }
    }

    private func preciseGap(from d1: Date, to d2: Date) -> String {
        let cal = Calendar.current
        let earlier = cal.startOfDay(for: min(d1, d2))
        let later   = cal.startOfDay(for: max(d1, d2))
        let c = cal.dateComponents([.year, .month, .day], from: earlier, to: later)
        let y = c.year  ?? 0
        let m = c.month ?? 0
        let d = c.day   ?? 0
        if y == 0 && m == 0 && d == 0 { return "Same day" }
        if y == 0 && m == 0 { return "\(d)d gap" }
        if y == 0 { return d > 0 ? "\(m)mo \(d)d gap" : "\(m)mo gap" }
        if m == 0 { return d > 0 ? "\(y)y \(d)d gap" : "\(y)y gap" }
        return d > 0 ? "\(y)y \(m)mo \(d)d gap" : "\(y)y \(m)mo gap"
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
}

// MARK: - Gap Comparison Card

struct GapComparisonCard: View {
    let person1: Person
    let person2: Person
    let onDismiss: () -> Void

    private var older:   Person { person1.birthday <= person2.birthday ? person1 : person2 }
    private var younger: Person { person1.birthday <= person2.birthday ? person2 : person1 }

    private var gapDescription: String {
        let cal = Calendar.current
        let earlier = cal.startOfDay(for: older.birthday)
        let later   = cal.startOfDay(for: younger.birthday)
        let c = cal.dateComponents([.year, .month, .day], from: earlier, to: later)
        let y = c.year ?? 0
        let m = c.month ?? 0
        let d = c.day ?? 0
        if y == 0 && m == 0 && d == 0 { return "Same birthday!" }
        if y == 0 && m == 0 { return "\(d) day\(d == 1 ? "" : "s") apart" }
        if y == 0 {
            let base = "\(m) month\(m == 1 ? "" : "s")"
            return d > 0 ? "\(base) \(d)d apart" : "\(base) apart"
        }
        if m == 0 {
            let base = "\(y) year\(y == 1 ? "" : "s")"
            return d > 0 ? "\(base) \(d)d apart" : "\(base) apart"
        }
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
