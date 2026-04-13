import SwiftUI
import SwiftData

struct PeopleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]
    @State private var showingAddPerson    = false
    @State private var selectedPerson: Person?
    @State private var searchText          = ""
    @State private var showingContactPicker = false
    @State private var importCandidates: [ImportCandidate] = []
    @State private var showingImportPreview = false

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
                    Button {
                        showingContactPicker = true
                    } label: {
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
                ContactPicker { contacts in
                    showingContactPicker = false
                    guard !contacts.isEmpty else { return }
                    importCandidates = makeImportCandidates(from: contacts, existing: people)
                    if !importCandidates.isEmpty {
                        showingImportPreview = true
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showingImportPreview) {
                ContactImportView(candidates: importCandidates) { selected in
                    for c in selected {
                        let person = Person(
                            name: c.name,
                            birthday: c.birthday ?? Date()
                        )
                        modelContext.insert(person)
                    }
                    NotificationManager.shared.rescheduleAll(people: people)
                }
            }
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
