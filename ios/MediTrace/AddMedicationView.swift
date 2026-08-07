import SwiftUI

struct AddMedicationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: MedicationStore
    @State private var name = ""
    @State private var dose = 100.0
    @State private var unit = "mg"
    @State private var halfLife = 8.0
    @State private var timeToPeak = 2.0

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        dose > 0 && halfLife > 0 && timeToPeak >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Name", text: $name)
                    HStack {
                        TextField("Default dose", value: $dose, format: .number)
                            .decimalInputKeyboard()
                        TextField("Unit", text: $unit)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 70)
                    }
                }
                Section {
                    HStack {
                        Text("Half-life")
                        Spacer()
                        TextField("hours", value: $halfLife, format: .number)
                            .decimalInputKeyboard()
                            .multilineTextAlignment(.trailing)
                        Text("hours").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Time to peak")
                        Spacer()
                        TextField("hours", value: $timeToPeak, format: .number)
                            .decimalInputKeyboard()
                            .multilineTextAlignment(.trailing)
                        Text("hours").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Pharmacokinetic parameters")
                } footer: {
                    Text("Time to peak is the time after a dose until the estimated level is highest. Confirm these parameters from the medication leaflet or your clinician.")
                }
            }
            .navigationTitle("Add Medication")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addMedication(
                            name: name,
                            dose: dose,
                            unit: unit,
                            halfLifeHours: halfLife,
                            timeToPeakHours: timeToPeak
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
