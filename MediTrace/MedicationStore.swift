import Foundation

@MainActor
final class MedicationStore: ObservableObject {
    @Published private(set) var medications: [Medication] = []
    @Published private(set) var doses: [DoseEvent] = []

    private struct Snapshot: Codable {
        var medications: [Medication]
        var doses: [DoseEvent]
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
        medications.removeAll { $0.id == medication.id }
        doses.removeAll { $0.medicationID == medication.id }
        save()
    }

    func addDose(for medication: Medication, amount: Double, at date: Date) {
        doses.append(DoseEvent(medicationID: medication.id, amount: amount, takenAt: date))
        doses.sort { $0.takenAt > $1.takenAt }
        save()
    }

    func deleteDose(_ dose: DoseEvent) {
        doses.removeAll { $0.id == dose.id }
        save()
    }

    func doses(for medication: Medication) -> [DoseEvent] {
        doses.filter { $0.medicationID == medication.id }.sorted { $0.takenAt > $1.takenAt }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        medications = snapshot.medications
        doses = snapshot.doses.sorted { $0.takenAt > $1.takenAt }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(Snapshot(medications: medications, doses: doses))
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
