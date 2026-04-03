import SwiftUI
import SwiftData
import PhotosUI

struct AddEditPersonView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Person.name) private var allPeople: [Person]

    var person: Person?

    @State private var name             = ""
    @State private var birthday         = Date()
    @State private var relationshipTag  = RelationshipTag.friend.rawValue
    @State private var notes            = ""
    @State private var selectedPhoto:   PhotosPickerItem?
    @State private var photoData:       Data?
    @State private var scheduleReminder = true

    // Relationship link pickers
    @State private var selectedSpouseID: UUID?
    @State private var selectedParentID: UUID?

    var isEditing: Bool { person != nil }

    // People available to link (exclude self)
    private var linkablePeople: [Person] {
        allPeople.filter { $0.id != person?.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── Photo ──────────────────────────────────────────────
                Section("Photo") {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            if let photoData, let img = UIImage(data: photoData) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 100, height: 100)
                                    VStack(spacing: 4) {
                                        Image(systemName: "camera.fill").font(.title2)
                                        Text("Add Photo").font(.caption2)
                                    }
                                    .foregroundStyle(.gray)
                                }
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                // ── Details ────────────────────────────────────────────
                Section("Details") {
                    TextField("Full Name", text: $name)
                    DatePicker("Birthday", selection: $birthday,
                               displayedComponents: .date)
                }

                // ── Relationship Tag ───────────────────────────────────
                Section("Relationship") {
                    Picker("Tag", selection: $relationshipTag) {
                        ForEach(RelationshipTag.allCases, id: \.rawValue) { tag in
                            Text("\(tag.emoji) \(tag.rawValue)").tag(tag.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    TextField("Notes  (e.g. \"Emily's brother\")", text: $notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // ── Tree Links ─────────────────────────────────────────
                Section {
                    // Spouse
                    Picker("Spouse / Partner", selection: $selectedSpouseID) {
                        Text("None").tag(UUID?.none)
                        ForEach(linkablePeople) { p in
                            Text(p.name).tag(Optional(p.id))
                        }
                    }
                    .pickerStyle(.menu)

                    // Parent
                    Picker("Parent in Tree", selection: $selectedParentID) {
                        Text("None").tag(UUID?.none)
                        ForEach(linkablePeople) { p in
                            Text(p.name).tag(Optional(p.id))
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Family Tree Links")
                } footer: {
                    Text("\"Parent in Tree\" links this person as a child of the selected person. Spouse links are shown side-by-side. Notes let you add context like \"Emily's brother\".")
                        .font(.caption)
                }

                // ── Reminder ───────────────────────────────────────────
                Section("Reminder") {
                    Toggle("Annual Birthday Reminder", isOn: $scheduleReminder)
                }
            }
            .navigationTitle(isEditing ? "Edit Person" : "Add Person")
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
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
            .onAppear { populateFromExisting() }
        }
    }

    // MARK: - Populate when editing

    private func populateFromExisting() {
        guard let person else { return }
        name            = person.name
        birthday        = person.birthday
        relationshipTag = person.relationshipTag
        notes           = person.notes
        photoData       = person.photoData
        selectedSpouseID = person.spouseID
        selectedParentID = person.parentID
    }

    // MARK: - Save

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if let person {
            // ── Edit existing ──
            let oldSpouseID = person.spouseID

            NotificationManager.shared.cancelNotification(for: person)
            person.name            = trimmedName
            person.birthday        = birthday
            person.relationshipTag = relationshipTag
            person.notes           = notes
            person.photoData       = photoData
            person.spouseID        = selectedSpouseID
            person.parentID        = selectedParentID

            // Keep spouse link bidirectional
            if let old = oldSpouseID, old != selectedSpouseID,
               let oldSpouse = allPeople.first(where: { $0.id == old }) {
                oldSpouse.spouseID = nil   // unlink old spouse
            }
            if let newID = selectedSpouseID,
               let newSpouse = allPeople.first(where: { $0.id == newID }) {
                newSpouse.spouseID = person.id
            }

            if scheduleReminder {
                NotificationManager.shared.scheduleNotification(for: person)
            }
        } else {
            // ── Add new ──
            let newPerson = Person(
                name: trimmedName,
                birthday: birthday,
                relationshipTag: relationshipTag
            )
            newPerson.notes    = notes
            newPerson.photoData = photoData
            newPerson.spouseID = selectedSpouseID
            newPerson.parentID = selectedParentID
            modelContext.insert(newPerson)

            // Keep spouse link bidirectional
            if let sid = selectedSpouseID,
               let spouse = allPeople.first(where: { $0.id == sid }) {
                spouse.spouseID = newPerson.id
            }

            if scheduleReminder {
                NotificationManager.shared.scheduleNotification(for: newPerson)
            }
        }
        dismiss()
    }
}
