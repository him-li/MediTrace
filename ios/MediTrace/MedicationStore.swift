import Foundation

@MainActor
final class MedicationStore: ObservableObject {
    @Published private(set) var medications: [Medication] = []
    @Published private(set) var doses: [DoseEvent] = []
    @Published private(set) var reminders: [MedicationReminder] = []

    private struct Snapshot: Codable {
        var medications: [Medication]
        var doses: [DoseEvent]
        var reminders: [MedicationReminder] = []

        private enum CodingKeys: String, CodingKey { case medications, doses, reminders }

        init(medications: [Medication], doses: [DoseEvent], reminders: [MedicationReminder]) {
            self.medications = medications
            self.doses = doses
            self.reminders = reminders
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            medications = try container.decode([Medication].self, forKey: .medications)
            doses = try container.decode([DoseEvent].self, forKey: .doses)
            reminders = try container.decodeIfPresent([MedicationReminder].self, forKey: .reminders) ?? []
        }
    }

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        load()
    }

    func addMedication(
        name: String,
        dose: Double,
        unit: String,
        halfLifeHours: Double,
        timeToPeakHours: Double
    ) {
        medications.append(Medication(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultDose: dose,
            unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
            halfLifeHours: halfLifeHours,
            timeToPeakHours: timeToPeakHours
        ))
        save()
    }

    func deleteMedication(_ medication: Medication) {
        reminders.filter { $0.medicationID == medication.id }.forEach { reminder in
            if let alarmID = reminder.alarmID { try? MedicationAlarmScheduler.cancel(id: alarmID) }
        }
        medications.removeAll { $0.id == medication.id }
        doses.removeAll { $0.medicationID == medication.id }
        reminders.removeAll { $0.medicationID == medication.id }
        save()
    }

    func addDose(for medication: Medication, amount: Double, at date: Date) {
        doses.append(DoseEvent(medicationID: medication.id, amount: amount, takenAt: date))
        doses.sort { $0.takenAt > $1.takenAt }
        save()
        Task { await rescheduleReminders(for: medication) }
    }

    func deleteDose(_ dose: DoseEvent) {
        let medication = medications.first { $0.id == dose.medicationID }
        doses.removeAll { $0.id == dose.id }
        save()
        if let medication { Task { await rescheduleReminders(for: medication) } }
    }

    func doses(for medication: Medication) -> [DoseEvent] {
        doses.filter { $0.medicationID == medication.id }.sorted { $0.takenAt > $1.takenAt }
    }

    func reminders(for medication: Medication) -> [MedicationReminder] {
        reminders.filter { $0.medicationID == medication.id }
    }

    func addReminder(
        for medication: Medication,
        trigger: MedicationReminder.Trigger,
        snoozeMinutes: Double
    ) async throws {
        var reminder = MedicationReminder(
            medicationID: medication.id,
            trigger: trigger,
            snoozeMinutes: snoozeMinutes
        )
        reminder = try await schedule(reminder, for: medication)
        reminders.append(reminder)
        save()
    }

    func deleteReminder(_ reminder: MedicationReminder) {
        if let alarmID = reminder.alarmID { try? MedicationAlarmScheduler.cancel(id: alarmID) }
        reminders.removeAll { $0.id == reminder.id }
        save()
    }

    func rescheduleReminders(for medication: Medication) async {
        for index in reminders.indices where reminders[index].medicationID == medication.id {
            if let oldID = reminders[index].alarmID { try? MedicationAlarmScheduler.cancel(id: oldID) }
            do {
                reminders[index] = try await schedule(reminders[index], for: medication)
            } catch {
                reminders[index].alarmID = nil
                reminders[index].nextFireDate = nil
            }
        }
        save()
    }

    func medication(id: UUID) -> Medication? {
        medications.first { $0.id == id }
    }

    private func schedule(
        _ reminder: MedicationReminder,
        for medication: Medication
    ) async throws -> MedicationReminder {
        let fireDate: Date?
        switch reminder.trigger {
        case .afterDuration(let hours):
            fireDate = Date.now.addingTimeInterval(hours * 3_600)
        case .belowAmount(let threshold):
            fireDate = Pharmacokinetics.firstDateBelow(
                threshold,
                medication: medication,
                doses: doses(for: medication)
            )
        }
        guard let fireDate else { throw ReminderError.noPredictedDate }

        var updated = reminder
        let alarmID = UUID()
        try await MedicationAlarmScheduler.schedule(
            id: alarmID,
            medication: medication,
            fireDate: fireDate,
            snoozeMinutes: reminder.snoozeMinutes
        )
        updated.alarmID = alarmID
        updated.nextFireDate = fireDate
        return updated
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        medications = snapshot.medications
        doses = snapshot.doses.sorted { $0.takenAt > $1.takenAt }
        reminders = snapshot.reminders
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(Snapshot(
                medications: medications,
                doses: doses,
                reminders: reminders
            ))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("保存数据失败：\(error.localizedDescription)")
        }
    }

    private static var defaultFileURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "MediTrace", directoryHint: .isDirectory)
            .appending(path: "medications.json")
    }
}

enum ReminderError: LocalizedError {
    case noPredictedDate

    var errorDescription: String? {
        String(localized: "无法根据当前记录预测提醒时间。请先添加一笔服药记录。")
    }
}
