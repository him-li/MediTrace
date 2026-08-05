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
                        "暂无提醒",
                        systemImage: "alarm",
                        description: Text("可按固定时长或估算剩余量创建系统闹钟。")
                    )
                } else {
                    ForEach(store.reminders(for: medication)) { reminder in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(reminderTitle(reminder)).font(.headline)
                            if let date = reminder.nextFireDate {
                                Text("下次提醒：\(date.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("延长 \(reminder.snoozeMinutes.formatted()) 分钟")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("删除", role: .destructive) { store.deleteReminder(reminder) }
                        }
                    }
                }
            }
            .navigationTitle("用药提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("添加提醒", systemImage: "plus") { showingAdd = true }
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
            String(localized: "服药后 \(hours.formatted()) 小时")
        case .belowAmount(let amount):
            String(localized: "低于 \(amount.formatted()) \(medication.unit)")
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
                Section("触发条件") {
                    Picker("提醒方式", selection: $mode) {
                        Text("固定时长").tag(Mode.duration)
                        Text("低于指定剩余量").tag(Mode.threshold)
                    }
                    .pickerStyle(.segmented)

                    if mode == .duration {
                        valueRow("服药后", value: $durationHours, suffix: String(localized: "小时"))
                    } else {
                        valueRow("低于", value: $threshold, suffix: medication.unit)
                    }
                }

                Section {
                    valueRow("延长时间", value: $snoozeMinutes, suffix: String(localized: "分钟"))
                } footer: {
                    Text("闹钟响起时可以选择延长。选择停止后，App 会要求记录新的服药剂量。")
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("添加提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await save() } }
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
            TextField("数值", value: value, format: .number)
                .keyboardType(.decimalPad)
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
