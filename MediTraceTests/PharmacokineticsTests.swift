import XCTest
@testable import MediTrace

final class PharmacokineticsTests: XCTestCase {
    func testOneDoseHalvesAfterOneHalfLife() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let medication = Medication(name: "Test", defaultDose: 100, unit: "mg", halfLifeHours: 8)
        let dose = DoseEvent(medicationID: medication.id, amount: 100, takenAt: start)

        let result = Pharmacokinetics.remainingAmount(
            at: start.addingTimeInterval(8 * 3_600),
            medication: medication,
            doses: [dose]
        )

        XCTAssertEqual(result, 50, accuracy: 0.0001)
    }

    func testMultipleDosesAreAdded() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let medication = Medication(name: "Test", defaultDose: 100, unit: "mg", halfLifeHours: 8)
        let doses = [
            DoseEvent(medicationID: medication.id, amount: 100, takenAt: start),
            DoseEvent(medicationID: medication.id, amount: 50, takenAt: start.addingTimeInterval(8 * 3_600))
        ]

        let result = Pharmacokinetics.remainingAmount(
            at: start.addingTimeInterval(8 * 3_600),
            medication: medication,
            doses: doses
        )

        XCTAssertEqual(result, 100, accuracy: 0.0001)
    }

    func testFutureDoseIsExcluded() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let medication = Medication(name: "Test", defaultDose: 100, unit: "mg", halfLifeHours: 8)
        let futureDose = DoseEvent(medicationID: medication.id, amount: 100, takenAt: now.addingTimeInterval(60))

        XCTAssertEqual(
            Pharmacokinetics.remainingAmount(at: now, medication: medication, doses: [futureDose]),
            0
        )
    }
}
