import Foundation

struct Medication: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var defaultDose: Double
    var unit: String
    var halfLifeHours: Double
    var createdAt = Date()
}

struct DoseEvent: Identifiable, Codable, Hashable {
    var id = UUID()
    var medicationID: UUID
    var amount: Double
    var takenAt: Date
}

struct ConcentrationPoint: Identifiable {
    let date: Date
    let amount: Double
    var id: Date { date }
}

enum Pharmacokinetics {
    static func remainingAmount(
        at date: Date,
        medication: Medication,
        doses: [DoseEvent]
    ) -> Double {
        guard medication.halfLifeHours > 0 else { return 0 }

        return doses
            .filter { $0.medicationID == medication.id && $0.takenAt <= date }
            .reduce(0) { total, dose in
                let elapsedHours = date.timeIntervalSince(dose.takenAt) / 3_600
                return total + dose.amount * pow(0.5, elapsedHours / medication.halfLifeHours)
            }
    }

    static func timeline(
        medication: Medication,
        doses: [DoseEvent],
        now: Date = .now,
        pastHours: Double = 24,
        futureHalfLives: Double = 5,
        intervalMinutes: Double = 30
    ) -> [ConcentrationPoint] {
        let start = now.addingTimeInterval(-pastHours * 3_600)
        let end = now.addingTimeInterval(max(24, medication.halfLifeHours * futureHalfLives) * 3_600)
        let step = intervalMinutes * 60

        return stride(from: start.timeIntervalSince1970,
                      through: end.timeIntervalSince1970,
                      by: step).map { timestamp in
            let date = Date(timeIntervalSince1970: timestamp)
            return ConcentrationPoint(
                date: date,
                amount: remainingAmount(at: date, medication: medication, doses: doses)
            )
        }
    }
}
