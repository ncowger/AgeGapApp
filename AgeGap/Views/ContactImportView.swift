import SwiftUI
import Contacts
import ContactsUI

// MARK: - CNContactPickerViewController wrapper

struct ContactPicker: UIViewControllerRepresentable {
    /// Called with the contacts the user selected
    var onSelect: ([CNContact]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // Fetch name + birthday
        picker.displayedPropertyKeys = [CNContactGivenNameKey,
                                        CNContactFamilyNameKey,
                                        CNContactBirthdayKey]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController,
                                context: Context) {}

    class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: ([CNContact]) -> Void
        init(onSelect: @escaping ([CNContact]) -> Void) { self.onSelect = onSelect }

        // Multi-select
        func contactPicker(_ picker: CNContactPickerViewController,
                           didSelect contacts: [CNContact]) {
            onSelect(contacts)
        }
        // Single-select fallback
        func contactPicker(_ picker: CNContactPickerViewController,
                           didSelect contact: CNContact) {
            onSelect([contact])
        }
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onSelect([])
        }
    }
}

// MARK: - Import preview sheet

struct ContactImportView: View {
    let candidates: [ImportCandidate]
    let onImport: ([ImportCandidate]) -> Void

    @State private var selected: Set<UUID> = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    ContentUnavailableView(
                        "No Birthdays Found",
                        systemImage: "birthday.cake",
                        description: Text("None of the selected contacts have a birthday saved.")
                    )
                } else {
                    List(candidates) { c in
                        HStack(spacing: 12) {
                            Image(systemName: selected.contains(c.id)
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected.contains(c.id) ? .blue : .secondary)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name).font(.headline)
                                if let bd = c.birthday {
                                    Text(bd.formatted(.dateTime.month(.wide).day().year()))
                                        .font(.caption).foregroundStyle(.secondary)
                                } else {
                                    Text("No birthday — will use today's date")
                                        .font(.caption).foregroundStyle(.orange)
                                }
                            }

                            Spacer()

                            if c.alreadyExists {
                                Text("Already added")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(Color(.systemGray5))
                                    .clipShape(Capsule())
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !c.alreadyExists else { return }
                            if selected.contains(c.id) { selected.remove(c.id) }
                            else { selected.insert(c.id) }
                        }
                        .opacity(c.alreadyExists ? 0.45 : 1)
                    }
                }
            }
            .navigationTitle("Import Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import (\(selected.count))") {
                        let toImport = candidates.filter { selected.contains($0.id) }
                        onImport(toImport)
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
            .onAppear {
                // Pre-select all non-duplicate candidates
                selected = Set(candidates.filter { !$0.alreadyExists }.map { $0.id })
            }
        }
    }
}

// MARK: - Import candidate model

struct ImportCandidate: Identifiable {
    let id = UUID()
    let name: String
    let birthday: Date?
    let alreadyExists: Bool
}

// MARK: - CNContact → ImportCandidate helper

func makeImportCandidates(from contacts: [CNContact],
                          existing: [Person]) -> [ImportCandidate] {
    let existingNames = Set(existing.map { $0.name.lowercased() })
    return contacts.map { contact in
        let name = [contact.givenName, contact.familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        let birthday: Date? = {
            guard let comps = contact.birthday else { return nil }
            // Use current year if none stored (common in Contacts)
            var resolved = comps
            if resolved.year == nil {
                resolved.year = Calendar.current.component(.year, from: Date())
            }
            return Calendar.current.date(from: resolved)
        }()

        return ImportCandidate(
            name: name.isEmpty ? "Unknown" : name,
            birthday: birthday,
            alreadyExists: existingNames.contains(name.lowercased())
        )
    }
    .filter { !$0.name.isEmpty && $0.name != "Unknown" }
    .sorted { ($0.birthday ?? .distantFuture) < ($1.birthday ?? .distantFuture) }
}
