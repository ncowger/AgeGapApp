import SwiftUI
import SwiftData
import PhotosUI

struct AddEditPersonView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.sortOrder) private var tags: [Tag]

    var person: Person?

    @State private var name = ""
    @State private var birthday = Date()
    @State private var relationshipTag = "Friend"
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var scheduleReminder = true

    var isEditing: Bool { person != nil }

    var body: some View {
        NavigationStack {
            Form {
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
                                        Image(systemName: "camera.fill")
                                            .font(.title2)
                                        Text("Add Photo")
                                            .font(.caption2)
                                    }
                                    .foregroundStyle(.gray)
                                }
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Details") {
                    TextField("Name", text: $name)
                    DatePicker("Birthday", selection: $birthday, displayedComponents: .date)
                }

                Section("Relationship") {
                    Picker("Tag", selection: $relationshipTag) {
                        ForEach(tags) { tag in
                            Text("\(tag.emoji) \(tag.name)").tag(tag.name)
                        }
                    }
                    .pickerStyle(.menu)
                }

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
            .onAppear {
                if let person {
                    name            = person.name
                    birthday        = person.birthday
                    relationshipTag = person.relationshipTag
                    photoData       = person.photoData
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let person {
            NotificationManager.shared.cancelNotification(for: person)
            person.name            = trimmedName
            person.birthday        = birthday
            person.relationshipTag = relationshipTag
            person.photoData       = photoData
            if scheduleReminder {
                NotificationManager.shared.scheduleNotification(for: person)
            }
        } else {
            let newPerson = Person(name: trimmedName, birthday: birthday, relationshipTag: relationshipTag, photoData: photoData)
            modelContext.insert(newPerson)
            if scheduleReminder {
                NotificationManager.shared.scheduleNotification(for: newPerson)
            }
        }
        dismiss()
    }
}
