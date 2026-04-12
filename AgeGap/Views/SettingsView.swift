import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var people: [Person]

    @AppStorage(ReminderKey.enabled)     private var remindersEnabled: Bool = true
    @AppStorage(ReminderKey.bdayEnabled) private var bdayEnabled:      Bool = true
    @AppStorage(ReminderKey.bdayDays)    private var bdayDays:         Int  = 0
    @AppStorage(ReminderKey.monthly)     private var monthlyEnabled:   Bool = false

    // Whether the reminder fires in advance (true) or on the birthday (false)
    private var isAdvance: Bool { bdayDays > 0 }

    var body: some View {
        NavigationStack {
            Form {

                // ── Master toggle ──────────────────────────────────────
                Section {
                    Toggle("Enable birthday reminders", isOn: $remindersEnabled)
                } footer: {
                    Text("When off, all birthday notifications are cancelled.")
                        .font(.caption)
                }

                // ── Birthday Reminder ──────────────────────────────────
                Section {
                    Toggle("Birthday reminder", isOn: $bdayEnabled)

                    if bdayEnabled {
                        Picker("Remind me", selection: Binding(
                            get: { isAdvance },
                            set: { adv in bdayDays = adv ? max(bdayDays, 1) : 0 }
                        )) {
                            Text("On their birthday").tag(false)
                            Text("In advance").tag(true)
                        }
                        .pickerStyle(.segmented)

                        if isAdvance {
                            Stepper(value: $bdayDays, in: 1...365) {
                                Text(daysLabel(bdayDays))
                            }
                        }
                    }
                } header: {
                    Text("Birthday Reminder")
                } footer: {
                    Text("Fires at 9 AM and applies to every person in your list.")
                        .font(.caption)
                }
                .disabled(!remindersEnabled)

                // ── Monthly Summary ────────────────────────────────────
                Section {
                    Toggle("Upcoming birthdays on the 1st", isOn: $monthlyEnabled)
                    if monthlyEnabled {
                        Label("A single notification on the 1st of each month listing everyone with a birthday that month.",
                              systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Monthly Summary")
                }
                .disabled(!remindersEnabled)

                // ── Stats ──────────────────────────────────────────────
                if remindersEnabled {
                    Section("Notification Slots") {
                        let total = activeNotificationCount
                        LabeledContent("People", value: "\(people.count)")
                        LabeledContent("Scheduled notifications", value: "\(total) of 64 max")
                        if total > 55 {
                            Label("Approaching iOS limit — consider disabling some reminders",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .onChange(of: remindersEnabled) { _, _ in reschedule() }
            .onChange(of: bdayEnabled)      { _, _ in reschedule() }
            .onChange(of: bdayDays)         { _, _ in reschedule() }
            .onChange(of: monthlyEnabled)   { _, _ in reschedule() }
        }
    }

    // MARK: - Helpers

    private func reschedule() {
        NotificationManager.shared.rescheduleAll(people: people)
    }

    private var activeNotificationCount: Int {
        (bdayEnabled ? people.count : 0) + (monthlyEnabled ? 12 : 0)
    }

    private func daysLabel(_ days: Int) -> String {
        if days == 1     { return "1 day before" }
        if days % 7 == 0 { let w = days / 7; return "\(w) week\(w == 1 ? "" : "s") before" }
        return "\(days) days before"
    }
}

// Kept for use in NotificationManager body text
func daysLabelStatic(_ days: Int) -> String {
    if days == 1     { return "1 day before" }
    if days % 7 == 0 { let w = days / 7; return "\(w) week\(w == 1 ? "" : "s") before" }
    return "\(days) days before"
}
