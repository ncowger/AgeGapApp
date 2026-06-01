import SwiftUI
import SwiftData

// MARK: - Share sheet wrapper

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let avc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        // iPad requires a source anchor for the popover — centre it on screen.
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root  = scene.windows.first?.rootViewController {
            avc.popoverPresentationController?.sourceView = root.view
            avc.popoverPresentationController?.sourceRect = CGRect(
                x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0
            )
            avc.popoverPresentationController?.permittedArrowDirections = []
        }
        return avc
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Main View

struct FamilyTreeView: View {
    @Query(sort: \Person.name) private var people: [Person]
    @State private var selectedPeople: [Person] = []

    // Zoom / pan state
    @State private var scale:      CGFloat = 1.0
    @State private var lastScale:  CGFloat = 1.0
    @State private var offset:     CGSize  = .zero
    @State private var lastOffset: CGSize  = .zero

    // Export state
    @State private var showingExportOptions = false
    @State private var exportedURL: URL?
    @State private var showingShareSheet   = false
    @State private var isExporting         = false

    // Detail sheet (long-press a node)
    @State private var detailPerson: Person?

    private let minScale: CGFloat = 0.15
    private let maxScale: CGFloat = 4.0

    // Cached layout — only recomputed when people or their relationships change,
    // NOT on every pan/zoom render frame.
    @State private var layout: TreeLayout = .empty
    private var layoutKey: String {
        people.map {
            "\($0.id)\($0.spouseID?.uuidString ?? "")\($0.parent1ID?.uuidString ?? "")\($0.parent2ID?.uuidString ?? "")"
        }.joined()
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
                } else {
                    // Zoomable + pannable tree canvas
                    GeometryReader { geo in
                        TreeCanvasView(
                            layout: layout,
                            selectedPeople: selectedPeople,
                            onTap: { handleTap($0) },
                            onLongPress: { detailPerson = $0 }
                        )
                        .scaleEffect(scale, anchor: .center)
                        .offset(offset)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .contentShape(Rectangle())
                        .gesture(zoomAndPanGesture)
                        .onTapGesture(count: 2) { resetView() }
                    }

                    // Bottom overlay: comparison card or hint pill
                    VStack {
                        Spacer()
                        if selectedPeople.count == 2 {
                            GapComparisonCard(
                                person1: selectedPeople[0],
                                person2: selectedPeople[1],
                                onDismiss: { selectedPeople = [] }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            HStack {
                                Spacer()
                                Label(
                                    selectedPeople.count == 1
                                        ? "Tap one more to compare"
                                        : "Tap two people to compare  •  Pinch to zoom",
                                    systemImage: selectedPeople.count == 1 ? "hand.tap" : "hand.pinch"
                                )
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.regularMaterial, in: Capsule())
                                .padding(16)
                            }
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedPeople.count)
                }
            }
            .navigationTitle("Family Tree")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if isExporting {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Button { showingExportOptions = true } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .disabled(people.isEmpty)
                        }
                        Button { resetView() } label: {
                            Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                        }
                        .disabled(people.isEmpty)
                    }
                }
                if !selectedPeople.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Clear") { selectedPeople = [] }
                    }
                }
            }
            .confirmationDialog("Export Tree", isPresented: $showingExportOptions, titleVisibility: .visible) {
                Button("Export as PNG") { Task { await exportTree(asPDF: false) } }
                Button("Export as PDF") { Task { await exportTree(asPDF: true)  } }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedURL { ShareSheet(url: url) }
            }
            .sheet(item: $detailPerson) { person in
                PersonDetailSheet(person: person)
            }
            .onAppear { layout = TreeLayoutEngine(people: people).buildLayout() }
            .onChange(of: layoutKey) { layout = TreeLayoutEngine(people: people).buildLayout() }
        }
    }

    // MARK: - Tap handling

    private func handleTap(_ person: Person) {
        withAnimation {
            if let idx = selectedPeople.firstIndex(where: { $0.id == person.id }) {
                selectedPeople.remove(at: idx)
            } else if selectedPeople.count < 2 {
                selectedPeople.append(person)
            } else {
                // Already have 2 — swap oldest selection out, bring new one in
                selectedPeople = [selectedPeople[1], person]
            }
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

    // MARK: - Export

    @MainActor
    private func exportTree(asPDF: Bool) async {
        isExporting = true
        defer { isExporting = false }

        // Render without selection highlights at 2× for crisp output, always in light mode
        let canvas = TreeCanvasView(layout: layout, selectedPeople: [], onTap: { _ in })
            .environment(\.colorScheme, .light)
            .background(Color(.systemBackground).environment(\.colorScheme, .light))
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 4.0

        let tmp = FileManager.default.temporaryDirectory

        if asPDF {
            // Render to a JPEG-compressed UIImage first, then embed it in a PDF page.
            // This avoids writing a raw uncompressed bitmap into the PDF, which cuts
            // file size dramatically (often 5–10×) at negligible visual cost.
            guard let img  = renderer.uiImage,
                  let jpeg = img.jpegData(compressionQuality: 0.82),
                  let compressed = UIImage(data: jpeg) else { return }

            let pageRect = CGRect(origin: .zero, size: img.size)
            let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)
            let data = pdfRenderer.pdfData { ctx in
                ctx.beginPage()
                compressed.draw(in: pageRect)
            }
            let url = tmp.appendingPathComponent("FamilyTree.pdf")
            try? data.write(to: url)
            exportedURL      = url
            showingShareSheet = true
        } else {
            guard let img  = renderer.uiImage,
                  let data = img.pngData() else { return }
            let url = tmp.appendingPathComponent("FamilyTree.png")
            try? data.write(to: url)
            exportedURL      = url
            showingShareSheet = true
        }
    }
}

// MARK: - Tree Canvas

struct TreeCanvasView: View {
    let layout:         TreeLayout
    let selectedPeople: [Person]
    let onTap:          (Person) -> Void
    var onLongPress:    ((Person) -> Void)? = nil

    private func isSelected(_ person: Person) -> Bool {
        selectedPeople.contains(where: { $0.id == person.id })
    }

    var body: some View {
        ZStack(alignment: .topLeading) {

                // ── Edge layer ───────────────────────────────────────────
                Canvas { ctx, _ in
                    for edge in layout.edges {
                        switch edge.kind {

                        case .spouseLink:
                            var path = Path()
                            path.move(to: edge.from)
                            path.addLine(to: edge.to)
                            ctx.stroke(
                                path,
                                with: .color(.secondary.opacity(0.55)),
                                style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                            )

                        case .parentChild:
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
                    TreePersonNode(person: pp.person, isSelected: isSelected(pp.person))
                        .frame(width: TreeLayoutEngine.nodeW, height: TreeLayoutEngine.nodeH)
                        .position(pp.position)
                        .onTapGesture { onTap(pp.person) }
                        .onLongPressGesture { onLongPress?(pp.person) }
                        .accessibilityLabel(pp.person.name)
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
                                    TreePersonNode(person: person, isSelected: isSelected(person))
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

// MARK: - Person Node

struct TreePersonNode: View {
    let person:     Person
    var isSelected: Bool = false

    private var isMe:     Bool    { person.isMe }
    private var nodeSize: CGFloat { isMe ? 60 : 52 }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Selection glow
                if isSelected {
                    Circle()
                        .fill(Color.orange.opacity(0.25))
                        .frame(width: nodeSize + 16, height: nodeSize + 16)
                }

                if let data = person.photoData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: nodeSize, height: nodeSize)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(colorForPerson(person))
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
                    .stroke(
                        isSelected ? Color.orange : (isMe ? Color.blue : Color(.systemBackground)),
                        lineWidth: isSelected ? 3 : (isMe ? 3 : 2)
                    )
                    .frame(width: nodeSize, height: nodeSize)
            )
            .shadow(color: isSelected ? .orange.opacity(0.4) : .black.opacity(isMe ? 0.2 : 0.1),
                    radius: isSelected ? 8 : (isMe ? 6 : 3))

            Text(person.name.components(separatedBy: " ").first ?? person.name)
                .font(.system(size: isMe ? 11 : 10, weight: isMe ? .bold : .medium))
                .foregroundStyle(isSelected ? .orange : (isMe ? .blue : .primary))
                .lineLimit(1)

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
                    Group {
                        if let data = person.photoData, let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Circle()
                                .fill(colorForPerson(person))
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
                        if person.isMe {
                            Text("⭐️ Me")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.15))
                                .clipShape(Capsule())
                        }
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
