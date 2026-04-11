import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var people: [Person]

    @AppStorage(ReminderKey.enabled)  private var remindersEnabled: Bool = true
    @AppStorage(ReminderKey.dayOf)    private var dayOfEnabled:     Bool = true
    @AppStorage(ReminderKey.adv1)     private var adv1Enabled:      Bool = false
    @AppStorage(ReminderKey.adv1Days) private var adv1Days:         Int  = 7
    @AppStorage(ReminderKey.adv2)     private var adv2Enabled:      Bool = false
    @AppStorage(ReminderKey.adv2Days) private var adv2Days:         Int  = 1
    @AppStorage(ReminderKey.monthly)  private var monthlyEnabled:   Bool = false

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

                // ── Birthday Reminders ─────────────────────────────────
                Section {
                    Toggle("On their birthday", isOn: $dayOfEnabled)

                    Toggle("First advance reminder", isOn: $adv1Enabled)
                    if adv1Enabled {
                        Stepper(value: $adv1Days, in: 1...365) {
                            Text(daysLabelStatic(adv1Days))
                        }
                    }

                    Toggle("Second advance reminder", isOn: $adv2Enabled)
                    if adv2Enabled {
                        Stepper(value: $adv2Days, in: 1...365) {
                            Text(daysLabelStatic(adv2Days))
                        }
                        if adv2Days == adv1Days && adv1Enabled {
                            Label("Same day as first reminder — change one",
                                  systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                } header: {
                    Text("Birthday Reminders")
                } footer: {
                    Text("All reminders fire at 9 AM and apply to every person in your list.")
                        .font(.caption)
                }
                .disabled(!remindersEnabled)

                // ── Monthly Summary ────────────────────────────────────
                Section {
                    Toggle("Upcoming birthdays on the 1st", isOn: $monthlyEnabled)
                    if monthlyEnabled {
                        Label("Sent at 9 AM on the 1st of each month",
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
            .onChange(of: dayOfEnabled)     { _, _ in reschedule() }
            .onChange(of: adv1Enabled)      { _, _ in reschedule() }
            .onChange(of: adv1Days)         { _, _ in reschedule() }
            .onChange(of: adv2Enabled)      { _, _ in reschedule() }
            .onChange(of: adv2Days)         { _, _ in reschedule() }
            .onChange(of: monthlyEnabled)   { _, _ in reschedule() }
        }
    }

    // MARK: - Helpers

    private func reschedule() {
        NotificationManager.shared.rescheduleAll(people: people)
    }

    private var activeNotificationCount: Int {
        let perPerson = (dayOfEnabled ? 1 : 0) + (adv1Enabled ? 1 : 0) + (adv2Enabled ? 1 : 0)
        let monthly   = monthlyEnabled ? 12 : 0
        return people.count * perPerson + monthly
    }
}

// Shared label helper used in NotificationManager body text
func daysLabelStatic(_ days: Int) -> String {
    if days == 1       { return "1 day before" }
    if days % 7 == 0   { let w = days / 7; return "\(w) week\(w == 1 ? "" : "s") before" }
    return "\(days) days before"
}
