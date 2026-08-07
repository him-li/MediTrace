import SwiftUI

struct ReminderListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: MedicationStore
    let medication: Medication
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                if store.reminders(for: medication).isEmpty {
                    ContentUnavailableView(
                        "No Reminders",
                        systemImage: "alarm",
                        description: Text("Create a system alarm based on elapsed time or estimated remaining amount.")
                    )
                } else {
                    ForEach(store.reminders(for: medication)) { reminder in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(reminderTitle(reminder)).font(.headline)
                            if let date = reminder.nextFireDate {
                                Text("Next reminder: \(date.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Snooze for \(reminder.snoozeMinutes.formatted()) min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) { store.deleteReminder(reminder) }
                        }
                    }
                }
            }
            .navigationTitle("Medication Reminders")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Reminder", systemImage: "plus") { showingAdd = true }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddReminderView(medication: medication)
            }
        }
    }

    private func reminderTitle(_ reminder: MedicationReminder) -> String {
        switch reminder.trigger {
        case .afterDuration(let hours):
            String(localized: "\(hours.formatted()) hours after dose")
        case .belowAmount(let amount):
            String(localized: "Below \(amount.formatted()) \(medication.unit)")
        }
    }
}

private struct AddReminderView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case duration
        case threshold
        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: MedicationStore
    let medication: Medication

    @State private var mode: Mode = .duration
    @State private var durationHours = 8.0
    @State private var threshold = 25.0
    @State private var snoozeMinutes = 10.0
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Trigger") {
                    Picker("Reminder type", selection: $mode) {
                        Text("Elapsed time").tag(Mode.duration)
                        Text("Below amount").tag(Mode.threshold)
                    }
                    .pickerStyle(.segmented)

                    if mode == .duration {
                        valueRow("After dose", value: $durationHours, suffix: String(localized: "hours"))
                    } else {
                        valueRow("Below", value: $threshold, suffix: medication.unit)
                    }
                }

                Section {
                    valueRow("Snooze duration", value: $snoozeMinutes, suffix: String(localized: "minutes"))
                } footer: {
                    Text("When the alarm rings, you can snooze it. After stopping it, the app requires you to record a new dose.")
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Add Reminder")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!isValid || isSaving)
                }
            }
        }
    }

    @ViewBuilder
    private func valueRow(_ title: LocalizedStringKey, value: Binding<Double>, suffix: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("Value", value: value, format: .number)
                .decimalInputKeyboard()
                .multilineTextAlignment(.trailing)
            Text(suffix).foregroundStyle(.secondary)
        }
    }

    private var isValid: Bool {
        snoozeMinutes > 0 && (mode == .duration ? durationHours > 0 : threshold >= 0)
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let trigger: MedicationReminder.Trigger = mode == .duration
            ? .afterDuration(hours: durationHours)
            : .belowAmount(threshold)
        do {
            try await store.addReminder(
                for: medication,
                trigger: trigger,
                snoozeMinutes: snoozeMinutes
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
