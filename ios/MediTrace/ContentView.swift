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
                        Label("No medications yet", systemImage: "pills")
                    } description: {
                        Text("Add a medication to record doses and view its half-life trend.")
                    } actions: {
                        Button("Add Medication") { showingAddMedication = true }
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
                            Text("The chart is a mathematical estimate, not a measured blood level or medical advice.")
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
                    Button("Add Medication", systemImage: "plus") { showingAddMedication = true }
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
                Text("Dose \(medication.defaultDose.formatted()) \(medication.unit) · Half-life \(medication.halfLifeHours.formatted()) h · Peak \(medication.timeToPeakHours.formatted()) h")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
