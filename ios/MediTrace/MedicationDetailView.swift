import Charts
import SwiftUI

struct MedicationDetailView: View {
    @EnvironmentObject private var store: MedicationStore
    let medication: Medication

    @State private var now = Date()
    @State private var showingDoseSheet = false
    @State private var showingReminders = false

    private var medicationDoses: [DoseEvent] { store.doses(for: medication) }
    private var currentAmount: Double {
        Pharmacokinetics.remainingAmount(at: now, medication: medication, doses: medicationDoses)
    }
    private var points: [ConcentrationPoint] {
        Pharmacokinetics.timeline(medication: medication, doses: medicationDoses, now: now)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 5) {
                    Text("Current estimated amount")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(currentAmount.formatted(.number.precision(.fractionLength(0...2)))) \(medication.unit)")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Estimated trend").font(.headline)
                    Chart(points) { point in
                        AreaMark(
                            x: .value("Time", point.date),
                            y: .value("Remaining amount", point.amount)
                        )
                        .foregroundStyle(.linearGradient(
                            colors: [.accentColor.opacity(0.5), .accentColor.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Remaining amount", point.amount)
                        )
                        .foregroundStyle(.tint)
                        .interpolationMethod(.linear)

                        RuleMark(x: .value("Now", now))
                            .foregroundStyle(.secondary)
                            .lineStyle(StrokeStyle(dash: [4]))
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.weekday().hour())
                        }
                    }
                    .frame(height: 240)
                    Text("Peaks in about \(medication.timeToPeakHours.formatted()) hours, then decays with a \(medication.halfLifeHours.formatted())-hour half-life. Every dose is added to the estimate.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Dose history").font(.headline)
                    if medicationDoses.isEmpty {
                        Text("No doses recorded")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 70)
                    } else {
                        ForEach(medicationDoses) { dose in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(dose.amount.formatted()) \(medication.unit)")
                                        .font(.body.weight(.medium))
                                    Text(dose.takenAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) { store.deleteDose(dose) } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.vertical, 5)
                            if dose.id != medicationDoses.last?.id { Divider() }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(medication.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Medication Reminders", systemImage: "alarm") { showingReminders = true }
                Button("Record Dose", systemImage: "plus.circle.fill") { showingDoseSheet = true }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                store.addDose(for: medication, amount: medication.defaultDose, at: .now)
                now = .now
            } label: {
                Label("Take \(medication.defaultDose.formatted()) \(medication.unit) now", systemImage: "pills.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .background(.bar)
        }
        .sheet(isPresented: $showingDoseSheet) {
            AddDoseView(medication: medication) { now = .now }
        }
        .sheet(isPresented: $showingReminders) {
            ReminderListView(medication: medication)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                now = .now
            }
        }
    }
}

struct AddDoseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: MedicationStore
    let medication: Medication
    let onSave: () -> Void
    var isRequired = false

    @State private var amount: Double
    @State private var date = Date()

    init(medication: Medication, isRequired: Bool = false, onSave: @escaping () -> Void) {
        self.medication = medication
        self.isRequired = isRequired
        self.onSave = onSave
        _amount = State(initialValue: medication.defaultDose)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dose") {
                    HStack {
                        TextField("Amount", value: $amount, format: .number)
                            .decimalInputKeyboard()
                        Text(medication.unit).foregroundStyle(.secondary)
                    }
                    DatePicker("Time taken", selection: $date, in: ...Date.now)
                }
            }
            .navigationTitle("Record Dose")
            .inlineNavigationTitle()
            .toolbar {
                if !isRequired {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addDose(for: medication, amount: amount, at: date)
                        onSave()
                        dismiss()
                    }
                    .disabled(amount <= 0)
                }
            }
        }
    }
}
