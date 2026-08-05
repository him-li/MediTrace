import AlarmKit
import AppIntents
import SwiftUI

struct MedicationAlarmMetadata: AlarmMetadata {
    let medicationID: UUID
}

struct RecordDoseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "记录新剂量"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "药物 ID")
    var medicationID: String

    init() {}

    init(medicationID: UUID) {
        self.medicationID = medicationID.uuidString
    }

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(medicationID, forKey: MedicationAlarmScheduler.pendingMedicationKey)
        return .result()
    }
}

enum MedicationAlarmScheduler {
    static let pendingMedicationKey = "pendingDoseMedicationID"

    static func schedule(
        id: UUID,
        medication: Medication,
        fireDate: Date,
        snoozeMinutes: Double
    ) async throws {
        let authorization = try await AlarmManager.shared.requestAuthorization()
        guard authorization == .authorized else { throw AlarmSchedulingError.notAuthorized }

        let repeatButton = AlarmButton(
            text: "忽略并延长",
            textColor: .orange,
            systemImageName: "clock.arrow.circlepath"
        )
        let alert = AlarmPresentation.Alert(
            title: "服药提醒",
            stopButton: AlarmButton(
                text: "停止并记录",
                textColor: .red,
                systemImageName: "stop.circle"
            ),
            secondaryButton: repeatButton,
            secondaryButtonBehavior: .countdown
        )
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: MedicationAlarmMetadata(medicationID: medication.id),
            tintColor: .blue
        )
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: Alarm.CountdownDuration(
                preAlert: nil,
                postAlert: snoozeMinutes * 60
            ),
            schedule: .fixed(fireDate),
            attributes: attributes,
            stopIntent: RecordDoseIntent(medicationID: medication.id),
            sound: .default
        )
        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
    }

    static func cancel(id: UUID) throws {
        try AlarmManager.shared.cancel(id: id)
    }
}

enum AlarmSchedulingError: LocalizedError {
    case notAuthorized

    var errorDescription: String? {
        String(localized: "没有系统闹钟权限。请在“设置”中允许 MediTrace 使用闹钟。")
    }
}
