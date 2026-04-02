import SwiftUI
import SwiftData
import UserNotifications

struct UpcomingBirthdaysView: View {
    @Query(sort: \Person.name) private var people: [Person]
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var todayBirthdays: [Person] {
        people.filter { $0.isBirthdayToday }
    }

    var upcomingBirthdays: [Person] {
        people
            .filter { !$0.isBirthdayToday }
            .sorted { $0.daysUntilBirthday < $1.daysUntilBirthday }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if notificationStatus == .denied {
                    HStack {
                        Image(systemName: "bell.slash").foregroundStyle(.orange)
                        Text("Enable notifications in Settings for birthday reminders")
                            .font(.caption)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                }

                List {
                    if !todayBirthdays.isEmpty {
                        Section("Today 🎂") {
                            ForEach(todayBirthdays) { person in
                                BirthdayRow(person: person)
                            }
                        }
                    }

                    Section(todayBirthdays.isEmpty ? "Upcoming" : "Coming Up") {
                        if upcomingBirthdays.isEmpty {
                            Text("No people added yet")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        } else {
                            ForEach(upcomingBirthdays) { person in
                                BirthdayRow(person: person)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Birthdays")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        NotificationManager.shared.requestPermission()
                    } label: {
                        Image(systemName: "bell.badge")
                    }
                }
            }
            .onAppear { checkStatus() }
        }
    }

    private func checkStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
            }
        }
        NotificationManager.shared.requestPermission()
    }
}

struct BirthdayRow: View {
    let person: Person

    var turningAge: Int {
        person.isBirthdayToday ? person.age : person.age + 1
    }

    var body: some View {
        HStack(spacing: 12) {
            personAvatar
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name).font(.headline)
                Text(person.birthday.formatted(.dateTime.month(.wide).day()))
                    .font(.caption).foregroundStyle(.secondary)
                Text("\(person.relationshipTag) • Turning \(turningAge)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if person.isBirthdayToday {
                Text("🎂").font(.title2)
            } else {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(person.daysUntilBirthday)")
                        .font(.title3).bold().foregroundStyle(.blue)
                    Text("days").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var personAvatar: some View {
        Group {
            if let data = person.photoData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Text(person.name.prefix(2).uppercased())
                    .font(.subheadline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(person.isBirthdayToday ? Color.orange : colorForRelationship(person.relationshipTag))
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }
}
