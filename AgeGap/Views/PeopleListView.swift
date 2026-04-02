import SwiftUI
import SwiftData

struct PeopleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]
    @State private var showingAddPerson = false
    @State private var selectedPerson: Person?
    @State private var searchText = ""
    @State private var selectedTag = "All"

    var allTags: [String] {
        ["All"] + RelationshipTag.allCases.map(\.rawValue)
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
                        ForEach(allTags, id: \.self) { tag in
                            Button(tag) { selectedTag = tag }
                                .buttonStyle(.bordered)
                                .tint(selectedTag == tag ? .blue : .gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                List {
                    ForEach(filteredPeople) { person in
                        PersonRowView(person: person)
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
            }
            .sheet(isPresented: $showingAddPerson) {
                AddEditPersonView()
            }
            .sheet(item: $selectedPerson) { person in
                AddEditPersonView(person: person)
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
                    .background(colorForRelationship(person.relationshipTag))
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
