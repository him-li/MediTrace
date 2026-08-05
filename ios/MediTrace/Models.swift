import Foundation

struct Medication: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var defaultDose: Double
    var unit: String
    var halfLifeHours: Double
    var timeToPeakHours: Double
    var createdAt = Date()

    init(
        id: UUID = UUID(),
        name: String,
        defaultDose: Double,
        unit: String,
        halfLifeHours: Double,
        timeToPeakHours: Double = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.defaultDose = defaultDose
        self.unit = unit
        self.halfLifeHours = halfLifeHours
        self.timeToPeakHours = timeToPeakHours
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, defaultDose, unit, halfLifeHours, timeToPeakHours, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        defaultDose = try container.decode(Double.self, forKey: .defaultDose)
        unit = try container.decode(String.self, forKey: .unit)
        halfLifeHours = try container.decode(Double.self, forKey: .halfLifeHours)
        timeToPeakHours = try container.decodeIfPresent(Double.self, forKey: .timeToPeakHours) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

struct DoseEvent: Identifiable, Codable, Hashable {
    var id = UUID()
    var medicationID: UUID
    var amount: Double
    var takenAt: Date
}

struct MedicationReminder: Identifiable, Codable, Hashable {
    enum Trigger: Codable, Hashable {
        case afterDuration(hours: Double)
        case belowAmount(Double)
    }

    var id = UUID()
    var medicationID: UUID
    var trigger: Trigger
    var snoozeMinutes: Double
    var alarmID: UUID?
    var nextFireDate: Date?
    var isEnabled = true
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
                let timeToPeak = max(0, medication.timeToPeakHours)
                let remaining: Double

                if timeToPeak > 0, elapsedHours < timeToPeak {
                    // A deliberately simple absorption phase: estimated systemic amount
                    // rises linearly until Tmax, then elimination begins from the peak.
                    remaining = dose.amount * elapsedHours / timeToPeak
                } else {
                    let eliminationHours = max(0, elapsedHours - timeToPeak)
                    remaining = dose.amount * pow(0.5, eliminationHours / medication.halfLifeHours)
                }
                return total + remaining
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

    static func firstDateBelow(
        _ threshold: Double,
        medication: Medication,
        doses: [DoseEvent],
        now: Date = .now
    ) -> Date? {
        let relevantDoses = doses.filter { $0.medicationID == medication.id && $0.takenAt <= now }
        guard !relevantDoses.isEmpty, threshold >= 0 else { return nil }

        let latestPeak = relevantDoses.map {
            $0.takenAt.addingTimeInterval(medication.timeToPeakHours * 3_600)
        }.max() ?? now
        var previousDate = max(now, latestPeak)
        var previousAmount = remainingAmount(at: previousDate, medication: medication, doses: relevantDoses)

        if previousAmount <= threshold { return now.addingTimeInterval(60) }

        let searchEnd = previousDate.addingTimeInterval(max(24, medication.halfLifeHours * 20) * 3_600)
        let step: TimeInterval = 15 * 60
        var date = previousDate.addingTimeInterval(step)

        while date <= searchEnd {
            let amount = remainingAmount(at: date, medication: medication, doses: relevantDoses)
            if amount <= threshold {
                var low = previousDate
                var high = date
                for _ in 0..<20 {
                    let middle = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
                    if remainingAmount(at: middle, medication: medication, doses: relevantDoses) > threshold {
                        low = middle
                    } else {
                        high = middle
                    }
                }
                return high
            }
            previousDate = date
            previousAmount = amount
            date = date.addingTimeInterval(step)
        }
        return nil
    }
}
