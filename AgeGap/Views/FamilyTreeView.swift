import SwiftUI
import SwiftData

// MARK: - Main View

struct FamilyTreeView: View {
    @Query(sort: \Person.name) private var people: [Person]
    @State private var selectedPerson: Person?

    // Zoom / pan state
    @State private var scale:      CGFloat = 1.0
    @State private var lastScale:  CGFloat = 1.0
    @State private var offset:     CGSize  = .zero
    @State private var lastOffset: CGSize  = .zero

    private let minScale: CGFloat = 0.15
    private let maxScale: CGFloat = 4.0

    private var layout: TreeLayout {
        TreeLayoutEngine(people: people).buildLayout()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if people.isEmpty {
                    ContentUnavailableView(
                        "No People Yet",
                        systemImage: "figure.2.and.child.holdinghands",
                        description: Text("Add people in the People tab to build your family tree")
                    )
                } else if people.first(where: { $0.relationshipTag == "Me" }) == nil {
                    // No "Me" person yet — guide the user
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 56))
                            .foregroundStyle(.secondary)
                        Text("Add yourself first")
                            .font(.headline)
                        Text("Tag one person as **Me** to anchor the family tree.\nEveryone else connects through you.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    // Zoomable + pannable tree canvas
                    GeometryReader { geo in
                        TreeCanvasView(layout: layout, onTap: { selectedPerson = $0 })
                            .scaleEffect(scale, anchor: .center)
                            .offset(offset)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .contentShape(Rectangle())
                            .gesture(zoomAndPanGesture)
                            .onTapGesture(count: 2) { resetView() }
                    }

                    // Hint pill (bottom right)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Label("Pinch to zoom  •  Double-tap to reset", systemImage: "hand.pinch")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.regularMaterial, in: Capsule())
                                .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("Family Tree")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { resetView() } label: {
                        Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                    }
                    .disabled(people.isEmpty)
                }
            }
            .sheet(item: $selectedPerson) { PersonDetailSheet(person: $0) }
        }
    }

    // MARK: - Gestures

    private var zoomAndPanGesture: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    let delta = value / lastScale
                    lastScale = value
                    scale = min(max(scale * delta, minScale), maxScale)
                }
                .onEnded { _ in lastScale = 1.0 },

            DragGesture()
                .onChanged { value in
                    offset = CGSize(
                        width:  lastOffset.width  + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in lastOffset = offset }
        )
    }

    private func resetView() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            scale      = 1.0
            lastScale  = 1.0
            offset     = .zero
            lastOffset = .zero
        }
    }
}

// MARK: - Tree Canvas

struct TreeCanvasView: View {
    let layout: TreeLayout
    let onTap:  (Person) -> Void

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            ZStack(alignment: .topLeading) {

                // ── Edge layer (Canvas) ──────────────────────────────────
                Canvas { ctx, _ in
                    for edge in layout.edges {
                        switch edge.kind {

                        case .spouseLink:
                            // Short dashed horizontal line connecting spouses
                            var path = Path()
                            path.move(to: edge.from)
                            path.addLine(to: edge.to)
                            ctx.stroke(
                                path,
                                with: .color(.secondary.opacity(0.55)),
                                style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                            )

                        case .parentChild:
                            // S-curve bezier from parent midpoint down to child
                            var path = Path()
                            path.move(to: edge.from)
                            let midY = (edge.from.y + edge.to.y) / 2
                            path.addCurve(
                                to: edge.to,
                                control1: CGPoint(x: edge.from.x, y: midY),
                                control2: CGPoint(x: edge.to.x,   y: midY)
                            )
                            ctx.stroke(
                                path,
                                with: .color(.secondary.opacity(0.45)),
                                style: StrokeStyle(lineWidth: 1.5)
                            )
                        }
                    }
                }
                .frame(width: layout.size.width, height: layout.size.height)

                // ── Node layer ───────────────────────────────────────────
                ForEach(layout.people) { pp in
                    TreePersonNode(person: pp.person)
                        .frame(width: TreeLayoutEngine.nodeW, height: TreeLayoutEngine.nodeH)
                        .position(pp.position)
                        .onTapGesture { onTap(pp.person) }
                }

                // ── Unlinked people strip ────────────────────────────────
                if !layout.unlinked.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Not yet linked to tree", systemImage: "link.badge.plus")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(layout.unlinked) { person in
                                    TreePersonNode(person: person)
                                        .frame(width: TreeLayoutEngine.nodeW,
                                               height: TreeLayoutEngine.nodeH)
                                        .onTapGesture { onTap(person) }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(14)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, TreeLayoutEngine.padding)
                    .offset(y: layout.size.height + 16)
                }
            }
            .frame(
                width:  layout.size.width,
                height: layout.size.height + (layout.unlinked.isEmpty ? 0 : 140)
            )
        }
    }
}

// MARK: - Person Node

struct TreePersonNode: View {
    let person: Person

    private var isMe:     Bool    { person.relationshipTag == "Me" }
    private var nodeSize: CGFloat { isMe ? 60 : 52 }

    var body: some View {
        VStack(spacing: 4) {
            // Avatar
            ZStack {
                if let data = person.photoData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: nodeSize, height: nodeSize)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(colorForRelationship(person.relationshipTag))
                        .frame(width: nodeSize, height: nodeSize)
                        .overlay(
                            Text(person.name.prefix(2).uppercased())
                                .font(.system(size: isMe ? 18 : 14, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }

                // ⭐️ badge for Me
                if isMe {
                    VStack {
                        HStack {
                            Spacer()
                            Text("⭐️")
                                .font(.system(size: 10))
                                .offset(x: 4, y: -4)
                        }
                        Spacer()
                    }
                    .frame(width: nodeSize, height: nodeSize)
                }
            }
            .overlay(
                Circle()
                    .stroke(isMe ? Color.blue : Color(.systemBackground), lineWidth: isMe ? 3 : 2)
                    .frame(width: nodeSize, height: nodeSize)
            )
            .shadow(color: .black.opacity(isMe ? 0.2 : 0.1), radius: isMe ? 6 : 3)

            // First name
            Text(person.name.components(separatedBy: " ").first ?? person.name)
                .font(.system(size: isMe ? 11 : 10, weight: isMe ? .bold : .medium))
                .foregroundStyle(isMe ? .blue : .primary)
                .lineLimit(1)

            // Age
            Text("Age \(person.age)")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Person Detail Sheet

struct PersonDetailSheet: View {
    let person: Person
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
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
                        Text(person.relationshipTag)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(colorForRelationship(person.relationshipTag).opacity(0.15))
                            .clipShape(Capsule())
                        if !person.notes.isEmpty {
                            Text(person.notes)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    VStack(spacing: 0) {
                        DetailInfoRow(label: "Birthday",
                                      value: person.birthday.formatted(date: .long, time: .omitted))
                        DetailInfoRow(label: "Age",
                                      value: "\(person.age) years old")
                        DetailInfoRow(label: "Next Birthday",
                                      value: "in \(person.daysUntilBirthday) days")
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 0)
                }
                .padding(.top, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct DetailInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.medium)
        }
        .padding(.vertical, 10)
        .overlay(Divider(), alignment: .bottom)
    }
}
