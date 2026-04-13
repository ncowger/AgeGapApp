import SwiftUI
import Contacts
import ContactsUI

// MARK: - CNContactPickerViewController wrapper

struct ContactPicker: UIViewControllerRepresentable {
    var onSelect: ([CNContact]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController,
                                context: Context) {}

    class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: ([CNContact]) -> Void
        init(onSelect: @escaping ([CNContact]) -> Void) { self.onSelect = onSelect }

        private let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey          as CNKeyDescriptor,
            CNContactFamilyNameKey         as CNKeyDescriptor,
            CNContactBirthdayKey           as CNKeyDescriptor,
            CNContactImageDataKey          as CNKeyDescriptor,
            CNContactImageDataAvailableKey as CNKeyDescriptor,
        ]

        // Re-fetch with explicit keys so birthday + photo are populated.
        // On iOS 18 the system "Share with App" dialog fires AFTER the picker
        // closes, so we delay 0.6s to let it resolve before querying the store.
        // If the identifier-based fetch still fails (limited access), we fall
        // back to a name-based search before giving up.
        private func refetchDelayed(_ contacts: [CNContact]) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                let store = CNContactStore()
                let result = contacts.map { contact -> CNContact in
                    // 1. Try identifier-based fetch (fastest, most accurate)
                    if let c = try? store.unifiedContact(
                            withIdentifier: contact.identifier,
                            keysToFetch: self.keys) {
                        return c
                    }
                    // 2. Fall back to name search (handles iOS 18 limited access)
                    let fullName = "\(contact.givenName) \(contact.familyName)"
                        .trimmingCharacters(in: .whitespaces)
                    let pred = CNContact.predicateForContacts(matchingName: fullName)
                    if let c = try? store.unifiedContacts(
                            matching: pred,
                            keysToFetch: self.keys).first {
                        return c
                    }
                    // 3. Return the original partial contact as a last resort
                    return contact
                }
                self.onSelect(result)
            }
        }

        func contactPicker(_ picker: CNContactPickerViewController,
                           didSelect contacts: [CNContact]) {
            refetchDelayed(contacts)
        }
        func contactPicker(_ picker: CNContactPickerViewController,
                           didSelect contact: CNContact) {
            refetchDelayed([contact])
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

                            // Contact photo or initials
                            contactAvatar(c)

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
                        onImport(candidates.filter { selected.contains($0.id) })
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
            .onAppear {
                selected = Set(candidates.filter { !$0.alreadyExists }.map { $0.id })
            }
        }
    }

    @ViewBuilder
    private func contactAvatar(_ c: ImportCandidate) -> some View {
        Group {
            if let data = c.photoData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Text(c.name.prefix(2).uppercased())
                    .font(.subheadline).bold().foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray)
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }
}

// MARK: - Import candidate model

struct ImportCandidate: Identifiable {
    let id       = UUID()
    let name:    String
    let birthday: Date?
    let photoData: Data?
    let alreadyExists: Bool
}

// MARK: - CNContact → ImportCandidate helper

func makeImportCandidates(from contacts: [CNContact],
                          existing: [Person]) -> [ImportCandidate] {
    let existingNames = Set(existing.map { $0.name.lowercased() })
    return contacts.compactMap { contact -> ImportCandidate? in
        let name = [contact.givenName, contact.familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }

        let birthday: Date? = {
            guard let comps = contact.birthday else { return nil }
            var resolved = comps
            if resolved.year == nil {
                resolved.year = Calendar.current.component(.year, from: Date())
            }
            return Calendar.current.date(from: resolved)
        }()

        let photoData: Data? = contact.imageDataAvailable ? contact.imageData : nil

        return ImportCandidate(
            name: name,
            birthday: birthday,
            photoData: photoData,
            alreadyExists: existingNames.contains(name.lowercased())
        )
    }
    .sorted { ($0.birthday ?? .distantFuture) < ($1.birthday ?? .distantFuture) }
}
