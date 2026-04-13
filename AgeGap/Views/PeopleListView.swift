import SwiftUI
import SwiftData
import Contacts

struct PeopleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]
    @State private var showingAddPerson    = false
    @State private var selectedPerson: Person?
    @State private var searchText          = ""
    @State private var showingContactPicker  = false
    @State private var showingContactsDenied = false

    var filteredPeople: [Person] {
        guard !searchText.isEmpty else { return people }
        return people.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredPeople) { person in
                    PersonRowView(person: person)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedPerson = person }
                }
                .onDelete(perform: deletePeople)
            }
            .searchable(text: $searchText, prompt: "Search people")
            .navigationTitle("Family & Friends")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddPerson = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { requestContactsAndShowPicker() } label: {
                        Label("Import", systemImage: "person.crop.circle.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPerson) {
                AddEditPersonView()
            }
            .sheet(item: $selectedPerson) { person in
                AddEditPersonView(person: person)
            }
            .sheet(isPresented: $showingContactPicker) {
                ContactBrowserView(existing: people) { contacts in
                    guard !contacts.isEmpty else { return }
                    for contact in contacts {
                        let name = "\(contact.givenName) \(contact.familyName)"
                            .trimmingCharacters(in: .whitespaces)
                        let person = Person(
                            name: name,
                            birthday: resolvedBirthday(contact.birthday) ?? Date()
                        )
                        person.photoData = contact.imageDataAvailable ? contact.imageData : nil
                        modelContext.insert(person)
                    }
                    NotificationManager.shared.rescheduleAll(people: people)
                }
            }
            .alert("Contacts Access Denied", isPresented: $showingContactsDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please allow Age Gap to access Contacts in Settings to import birthdays.")
            }
        }
    }

    // Request Contacts permission first so the re-fetch inside the picker works on first use
    private func requestContactsAndShowPicker() {
        let store = CNContactStore()
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited:
            showingContactPicker = true
        case .notDetermined:
            store.requestAccess(for: .contacts) { granted, _ in
                DispatchQueue.main.async {
                    if granted { showingContactPicker = true }
                    else { showingContactsDenied = true }
                }
            }
        default:
            showingContactsDenied = true
        }
    }

    private func deletePeople(at offsets: IndexSet) {
        let toDelete    = offsets.map { filteredPeople[$0] }
        let deletedIDs  = Set(toDelete.map { $0.id })
        toDelete.forEach { modelContext.delete($0) }
        let remaining   = people.filter { !deletedIDs.contains($0.id) }
        NotificationManager.shared.rescheduleAll(people: remaining)
    }
}

struct PersonRowView: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            personAvatar
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(person.name).font(.headline)
                    if person.isMe {
                        Text("⭐️").font(.caption)
                    }
                }
                HStack(spacing: 4) {
                    Text("Age \(person.age)")
                    if !person.notes.isEmpty {
                        Text("•")
                        Text(person.notes).lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            birthdayCountdown
        }
        .padding(.vertical, 4)
    }

    private var personAvatar: some View {
        Group {
            if let data = person.photoData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(person.name.prefix(2).uppercased())
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(colorForPerson(person))
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
    }

    private var birthdayCountdown: some View {
        Group {
            if person.isBirthdayToday {
                Text("🎂 Today!")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .bold()
            } else {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(person.daysUntilBirthday)d")
                        .font(.caption).bold()
                    Text("until")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
