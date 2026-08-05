import Charts
import SwiftUI

struct MedicationDetailView: View {
    @EnvironmentObject private var store: MedicationStore
    let medication: Medication

    @State private var now = Date()
    @State private var showingDoseSheet = false

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
                    Text("当前估算剩余量")
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
                    Text("估算趋势").font(.headline)
                    Chart(points) { point in
                        AreaMark(
                            x: .value("时间", point.date),
                            y: .value("剩余量", point.amount)
                        )
                        .foregroundStyle(.linearGradient(
                            colors: [.accentColor.opacity(0.5), .accentColor.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        LineMark(
                            x: .value("时间", point.date),
                            y: .value("剩余量", point.amount)
                        )
                        .foregroundStyle(.tint)
                        .interpolationMethod(.linear)

                        RuleMark(x: .value("现在", now))
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
                    Text("按半衰期 \(medication.halfLifeHours.formatted()) 小时计算；每次补服都会叠加。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("服用记录").font(.headline)
                    if medicationDoses.isEmpty {
                        Text("暂无记录")
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
            ToolbarItem(placement: .primaryAction) {
                Button("记录服用", systemImage: "plus.circle.fill") { showingDoseSheet = true }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                store.addDose(for: medication, amount: medication.defaultDose, at: .now)
                now = .now
            } label: {
                Label("现在服用 \(medication.defaultDose.formatted()) \(medication.unit)", systemImage: "pills.fill")
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
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                now = .now
            }
        }
    }
}

private struct AddDoseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: MedicationStore
    let medication: Medication
    let onSave: () -> Void

    @State private var amount: Double
    @State private var date = Date()

    init(medication: Medication, onSave: @escaping () -> Void) {
        self.medication = medication
        self.onSave = onSave
        _amount = State(initialValue: medication.defaultDose)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("本次服用") {
                    HStack {
                        TextField("剂量", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                        Text(medication.unit).foregroundStyle(.secondary)
                    }
                    DatePicker("服用时间", selection: $date, in: ...Date.now)
                }
            }
            .navigationTitle("记录服用")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
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
