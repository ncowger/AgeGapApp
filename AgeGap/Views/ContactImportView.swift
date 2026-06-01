import SwiftUI
import Contacts

// MARK: - Custom Contact Browser
// Queries CNContactStore directly — avoids CNContactPickerViewController's
// iOS 18 "Share with App" timing race where the delegate fires before
// the system grants access to refetch full contact data.

struct ContactBrowserView: View {
    let existing: [Person]
    let onSelect: ([CNContact]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var allContacts: [CNContact] = []
    @State private var selected:    Set<String>  = []   // contact identifiers
    @State private var isLoading    = true
    @State private var searchText   = ""

    private static let keys: [CNKeyDescriptor] = [
        CNContactGivenNameKey          as CNKeyDescriptor,
        CNContactFamilyNameKey         as CNKeyDescriptor,
        CNContactBirthdayKey           as CNKeyDescriptor,
        CNContactImageDataKey          as CNKeyDescriptor,
        CNContactImageDataAvailableKey as CNKeyDescriptor,
    ]

    private var filtered: [CNContact] {
        guard !searchText.isEmpty else { return allContacts }
        let q = searchText.lowercased()
        return allContacts.filter {
            "\($0.givenName) \($0.familyName)".lowercased().contains(q)
        }
    }

    private var existingNames: Set<String> {
        Set(existing.map { $0.name.lowercased() })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar lives in the view body — never displaced by the keyboard
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search contacts", text: $searchText)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                if isLoading {
                    ProgressView("Loading contacts…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if allContacts.isEmpty {
                    ContentUnavailableView(
                        "No Contacts with Birthdays",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("Add birthdays to your contacts in the Contacts app first.")
                    )
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(filtered, id: \.identifier) { contact in
                        contactRow(contact)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Choose Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        let chosen = allContacts.filter { selected.contains($0.identifier) }
                        onSelect(chosen)
                        dismiss()
                    } label: {
                        Text(selected.isEmpty ? "Import" : "Import (\(selected.count))")
                            .bold()
                    }
                    .disabled(selected.isEmpty)
                }
            }
            .onAppear(perform: loadContacts)
        }
    }

    @ViewBuilder
    private func contactRow(_ contact: CNContact) -> some View {
        let name      = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        let isDupe    = existingNames.contains(name.lowercased())
        let isChosen  = selected.contains(contact.identifier)

        HStack(spacing: 12) {
            Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isChosen ? .blue : .secondary)
                .font(.title3)

            // Avatar
            Group {
                if contact.imageDataAvailable, let data = contact.imageData,
                   let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Text(String(name.prefix(2)).uppercased())
                        .font(.subheadline).bold().foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.gray)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline)
                if let bd = resolvedBirthday(contact.birthday) {
                    Text(bd.formatted(.dateTime.month(.wide).day().year()))
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("No birthday stored")
                        .font(.caption).foregroundStyle(.orange)
                }
            }

            Spacer()

            if isDupe {
                Text("Already added")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
        }
        .opacity(isDupe ? 0.45 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isDupe else { return }
            if isChosen { selected.remove(contact.identifier) }
            else        { selected.insert(contact.identifier) }
        }
    }

    // MARK: - Load contacts from store

    private func loadContacts() {
        DispatchQueue.global(qos: .userInitiated).async {
            let store   = CNContactStore()
            let request = CNContactFetchRequest(keysToFetch: Self.keys)
            var result: [CNContact] = []
            try? store.enumerateContacts(with: request) { contact, _ in
                let name = "\(contact.givenName) \(contact.familyName)"
                    .trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                result.append(contact)
            }
            result.sort {
                "\($0.givenName) \($0.familyName)" < "\($1.givenName) \($1.familyName)"
            }
            DispatchQueue.main.async {
                allContacts = result
                isLoading = false
            }
        }
    }
}

// MARK: - Helpers

func resolvedBirthday(_ comps: DateComponents?) -> Date? {
    guard var c = comps else { return nil }
    if c.year == nil {
        let cal = Calendar.current
        c.year = cal.component(.year, from: Date())
        // If the resulting date is in the future (e.g. Dec birthday, imported in April),
        // step back to the previous year so the date is always in the past and
        // compatible with the DatePicker's upper bound of today.
        if let candidate = cal.date(from: c), candidate > Date() {
            c.year! -= 1
        }
    }
    return Calendar.current.date(from: c)
}
