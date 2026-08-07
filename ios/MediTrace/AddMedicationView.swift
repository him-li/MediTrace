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
                Section("药物") {
                    TextField("名称", text: $name)
                    HStack {
                        TextField("单次剂量", value: $dose, format: .number)
                            .decimalInputKeyboard()
                        TextField("单位", text: $unit)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 70)
                    }
                }
                Section {
                    HStack {
                        Text("半衰期")
                        Spacer()
                        TextField("小时", value: $halfLife, format: .number)
                            .decimalInputKeyboard()
                            .multilineTextAlignment(.trailing)
                        Text("小时").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("达到峰值时间")
                        Spacer()
                        TextField("小时", value: $timeToPeak, format: .number)
                            .decimalInputKeyboard()
                            .multilineTextAlignment(.trailing)
                        Text("小时").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("药代参数")
                } footer: {
                    Text("达到峰值时间指服药后达到最高估算水平所需的时间。请从药品说明书或医生处确认参数。")
                }
            }
            .navigationTitle("添加药物")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
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
