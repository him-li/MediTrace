import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: MedicationStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingAddMedication = false
    @State private var requiredDoseMedication: Medication?

    var body: some View {
        NavigationStack {
            Group {
                if store.medications.isEmpty {
                    ContentUnavailableView {
                        Label("还没有药物", systemImage: "pills")
                    } description: {
                        Text("添加药物后即可记录服用时间并查看半衰期趋势。")
                    } actions: {
                        Button("添加药物") { showingAddMedication = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            ForEach(store.medications) { medication in
                                NavigationLink(value: medication) {
                                    MedicationRow(medication: medication)
                                }
                            }
                            .onDelete { offsets in
                                offsets.map { store.medications[$0] }.forEach(store.deleteMedication)
                            }
                        } footer: {
                            Text("曲线为数学估算，不代表真实血药浓度或医疗建议。")
                        }
                    }
                }
            }
            .navigationTitle("MediTrace")
            .navigationDestination(for: Medication.self) { medication in
                MedicationDetailView(medication: medication)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("添加药物", systemImage: "plus") { showingAddMedication = true }
                }
            }
            .sheet(isPresented: $showingAddMedication) {
                AddMedicationView()
            }
            .requiredItemCover(item: $requiredDoseMedication) { medication in
                AddDoseView(medication: medication, isRequired: true) {
                    requiredDoseMedication = nil
                }
                .interactiveDismissDisabled()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { consumePendingDoseRequest() }
            }
            .onAppear { consumePendingDoseRequest() }
        }
    }

    private func consumePendingDoseRequest() {
        let defaults = UserDefaults.standard
        guard let value = defaults.string(forKey: MedicationAlarmScheduler.pendingMedicationKey),
              let id = UUID(uuidString: value),
              let medication = store.medication(id: id) else { return }
        defaults.removeObject(forKey: MedicationAlarmScheduler.pendingMedicationKey)
        requiredDoseMedication = medication
    }
}

private struct MedicationRow: View {
    let medication: Medication

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "pills.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 42, height: 42)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(medication.name).font(.headline)
                Text("常用剂量 \(medication.defaultDose.formatted()) \(medication.unit) · 半衰期 \(medication.halfLifeHours.formatted()) 小时 · 峰值 \(medication.timeToPeakHours.formatted()) 小时")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
