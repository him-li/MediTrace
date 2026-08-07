import Foundation

#if os(iOS)
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
#elseif os(macOS)
import AppKit
import UserNotifications
#endif

enum MedicationAlarmScheduler {
    static let pendingMedicationKey = "pendingDoseMedicationID"
    #if os(macOS)
    static let categoryID = "MEDICATION_REMINDER"
    static let snoozeActionID = "SNOOZE_MEDICATION_REMINDER"
    static let recordActionID = "RECORD_MEDICATION_DOSE"
    static let medicationIDKey = "medicationID"
    static let snoozeMinutesKey = "snoozeMinutes"
    #endif

    static func schedule(
        id: UUID,
        medication: Medication,
        fireDate: Date,
        snoozeMinutes: Double
    ) async throws {
        #if os(iOS)
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
            countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: snoozeMinutes * 60),
            schedule: .fixed(fireDate),
            attributes: attributes,
            stopIntent: RecordDoseIntent(medicationID: medication.id),
            sound: .default
        )
        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
        #elseif os(macOS)
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else { throw AlarmSchedulingError.notAuthorized }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "服药提醒")
        content.body = String(localized: "该记录新的服药剂量了。")
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.userInfo = [
            medicationIDKey: medication.id.uuidString,
            snoozeMinutesKey: snoozeMinutes
        ]
        let delay = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        try await center.add(UNNotificationRequest(
            identifier: id.uuidString,
            content: content,
            trigger: trigger
        ))
        #endif
    }

    static func cancel(id: UUID) throws {
        #if os(iOS)
        try AlarmManager.shared.cancel(id: id)
        #elseif os(macOS)
        let identifiers = [id.uuidString]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
        #endif
    }
}

#if os(macOS)
final class MacAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let snooze = UNNotificationAction(
            identifier: MedicationAlarmScheduler.snoozeActionID,
            title: String(localized: "忽略并延长")
        )
        let record = UNNotificationAction(
            identifier: MedicationAlarmScheduler.recordActionID,
            title: String(localized: "停止并记录"),
            options: [.foreground]
        )
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: MedicationAlarmScheduler.categoryID,
                actions: [snooze, record],
                intentIdentifiers: [],
                options: [.customDismissAction]
            )
        ])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let content = response.notification.request.content
        let action = response.actionIdentifier
        if action == MedicationAlarmScheduler.snoozeActionID ||
            action == UNNotificationDismissActionIdentifier {
            let minutes = content.userInfo[MedicationAlarmScheduler.snoozeMinutesKey] as? Double ?? 10
            let request = UNNotificationRequest(
                identifier: response.notification.request.identifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: max(60, minutes * 60),
                    repeats: false
                )
            )
            try? await center.add(request)
            return
        }

        if action == MedicationAlarmScheduler.recordActionID ||
            action == UNNotificationDefaultActionIdentifier,
           let medicationID = content.userInfo[MedicationAlarmScheduler.medicationIDKey] as? String {
            UserDefaults.standard.set(
                medicationID,
                forKey: MedicationAlarmScheduler.pendingMedicationKey
            )
            await MainActor.run { NSApp.activate(ignoringOtherApps: true) }
        }
    }
}
#endif

enum AlarmSchedulingError: LocalizedError {
    case notAuthorized

    var errorDescription: String? {
        #if os(macOS)
        String(localized: "没有系统通知权限。请在“系统设置”中允许 MediTrace 发送通知。")
        #else
        String(localized: "没有系统闹钟权限。请在“设置”中允许 MediTrace 使用闹钟。")
        #endif
    }
}
