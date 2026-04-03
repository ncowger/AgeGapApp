import SwiftUI
import SwiftData

struct PeopleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \Tag.sortOrder) private var tags: [Tag]
    @State private var showingAddPerson = false
    @State private var selectedPerson: Person?
    @State private var searchText = ""
    @State private var selectedTag = "All"
    @State private var showingTagManager = false

    var allTagNames: [String] {
        ["All"] + tags.map(\.name)
    }

    var filteredPeople: [Person] {
        people.filter { person in
            let matchesSearch = searchText.isEmpty || person.name.localizedCaseInsensitiveContains(searchText)
            let matchesTag = selectedTag == "All" || person.relationshipTag == selectedTag
            return matchesSearch && matchesTag
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allTagNames, id: \.self) { tagName in
                            Button {
                                selectedTag = tagName
                            } label: {
                                if tagName == "All" {
                                    Text("All")
                                } else {
                                    Text("\(tags.emoji(for: tagName)) \(tagName)")
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(selectedTag == tagName ? .blue : .gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                List {
                    ForEach(filteredPeople) { person in
                        PersonRowView(person: person, tags: tags)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedPerson = person }
                    }
                    .onDelete(perform: deletePeople)
                }
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
                    Button { showingTagManager = true } label: {
                        Label("Tags", systemImage: "tag")
                    }
                }
            }
            .sheet(isPresented: $showingAddPerson) {
                AddEditPersonView()
            }
            .sheet(item: $selectedPerson) { person in
                AddEditPersonView(person: person)
            }
            .sheet(isPresented: $showingTagManager) {
                TagManagementView()
            }
        }
    }

    private func deletePeople(at offsets: IndexSet) {
        for index in offsets {
            let person = filteredPeople[index]
            NotificationManager.shared.cancelNotification(for: person)
            modelContext.delete(person)
        }
    }
}

struct PersonRowView: View {
    let person: Person
    let tags: [Tag]

    var body: some View {
        HStack(spacing: 12) {
            personAvatar
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(person.relationshipTag)
                    Text("•")
                    Text("Age \(person.age)")
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
                    .background(tags.color(for: person.relationshipTag))
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
