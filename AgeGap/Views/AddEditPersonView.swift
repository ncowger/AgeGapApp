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
    @State private var isMe             = false
    @State private var notes            = ""
    @State private var selectedPhoto:   PhotosPickerItem?
    @State private var photoData:       Data?
    @State private var scheduleReminder = true

    // Tree link pickers
    @State private var selectedSpouseID: UUID?
    @State private var selectedParentID: UUID?

    var isEditing: Bool { person != nil }

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
                    let currentMe = allPeople.first(where: { $0.isMe && $0.id != person?.id })
                    Toggle("This is me ⭐️", isOn: $isMe)
                    if let currentMe, !isMe {
                        Text("Currently set to \(currentMe.name) — enabling this will transfer it")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // ── Notes ──────────────────────────────────────────────
                Section {
                    TextField("e.g. \"Dad's side\", \"College friend\"", text: $notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Notes")
                }

                // ── Tree Links ─────────────────────────────────────────
                Section {
                    Picker("Spouse / Partner", selection: $selectedSpouseID) {
                        Text("None").tag(UUID?.none)
                        ForEach(linkablePeople) { p in
                            Text(p.name).tag(Optional(p.id))
                        }
                    }
                    .pickerStyle(.menu)

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
                    Text("\"Parent in Tree\" links this person as a child of the selected person. Spouse links are shown side-by-side.")
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
        name             = person.name
        birthday         = person.birthday
        isMe             = person.isMe
        notes            = person.notes
        photoData        = person.photoData
        selectedSpouseID = person.spouseID
        selectedParentID = person.parentID
    }

    // MARK: - Save

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        // Enforce single "Me" — clear the flag on everyone else first
        if isMe {
            allPeople.filter { $0.id != person?.id }.forEach { $0.isMe = false }
        }

        if let person {
            let oldSpouseID = person.spouseID

            NotificationManager.shared.cancelNotification(for: person)
            person.name      = trimmedName
            person.birthday  = birthday
            person.isMe      = isMe
            person.notes     = notes
            person.photoData = photoData
            person.spouseID  = selectedSpouseID
            person.parentID  = selectedParentID

            if let old = oldSpouseID, old != selectedSpouseID,
               let oldSpouse = allPeople.first(where: { $0.id == old }) {
                oldSpouse.spouseID = nil
            }
            if let newID = selectedSpouseID,
               let newSpouse = allPeople.first(where: { $0.id == newID }) {
                newSpouse.spouseID = person.id
            }

            if scheduleReminder {
                NotificationManager.shared.scheduleNotification(for: person)
            }
        } else {
            let newPerson = Person(name: trimmedName, birthday: birthday, isMe: isMe)
            newPerson.notes     = notes
            newPerson.photoData = photoData
            newPerson.spouseID  = selectedSpouseID
            newPerson.parentID  = selectedParentID
            modelContext.insert(newPerson)

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
