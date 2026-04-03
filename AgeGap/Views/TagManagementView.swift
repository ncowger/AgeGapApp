import SwiftUI
import SwiftData

// MARK: - Tag Management (list + delete)

struct TagManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.sortOrder) private var tags: [Tag]
    @State private var showingAddTag = false
    @State private var editingTag: Tag?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(tags) { tag in
                        TagRow(tag: tag)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !tag.isBuiltIn { editingTag = tag }
                            }
                    }
                    .onDelete(perform: deleteTags)
                } footer: {
                    Text("Built-in tags cannot be deleted. Tap a custom tag to edit it.")
                        .font(.caption)
                }
            }
            .navigationTitle("Manage Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddTag = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTag) {
                AddEditTagView()
            }
            .sheet(item: $editingTag) { tag in
                AddEditTagView(tag: tag)
            }
        }
    }

    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            let tag = tags[index]
            guard !tag.isBuiltIn else { continue }
            modelContext.delete(tag)
        }
    }
}

struct TagRow: View {
    let tag: Tag

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(tag.color)
                .frame(width: 28, height: 28)
                .overlay(
                    Text(tag.emoji)
                        .font(.system(size: 14))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name).font(.body)
                if tag.isBuiltIn {
                    Text("Built-in").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !tag.isBuiltIn {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add / Edit Tag

struct AddEditTagView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.sortOrder) private var tags: [Tag]

    var tag: Tag?

    @State private var name = ""
    @State private var emoji = ""
    @State private var colorName = "gray"

    var isEditing: Bool { tag != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Label") {
                    TextField("Name (e.g. Colleague)", text: $name)
                    TextField("Emoji (e.g. 💼)", text: $emoji)
                        .onChange(of: emoji) { _, new in
                            // Trim to a single grapheme cluster
                            if new.count > 1 {
                                emoji = String(new.unicodeScalars.first.map(Character.init) ?? "👤")
                            }
                        }
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(TagColor.allCases, id: \.rawValue) { tc in
                            Circle()
                                .fill(tc.color)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle().stroke(Color.primary, lineWidth: colorName == tc.rawValue ? 3 : 0)
                                )
                                .onTapGesture { colorName = tc.rawValue }
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }

                Section("Preview") {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(TagColor(rawValue: colorName)?.color ?? .gray)
                            .frame(width: 40, height: 40)
                            .overlay(Text(emoji.isEmpty ? "?" : emoji).font(.system(size: 18)))
                        Text(name.isEmpty ? "Tag name" : name)
                            .foregroundStyle(name.isEmpty ? .secondary : .primary)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Tag" : "New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let tag {
                    name      = tag.name
                    emoji     = tag.emoji
                    colorName = tag.colorName
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let resolvedEmoji = emoji.isEmpty ? "👤" : emoji
        if let tag {
            tag.name      = trimmed
            tag.emoji     = resolvedEmoji
            tag.colorName = colorName
        } else {
            let nextOrder = (tags.map(\.sortOrder).max() ?? 0) + 1
            let newTag = Tag(name: trimmed, emoji: resolvedEmoji, colorName: colorName, isBuiltIn: false, sortOrder: nextOrder)
            modelContext.insert(newTag)
        }
        dismiss()
    }
}
