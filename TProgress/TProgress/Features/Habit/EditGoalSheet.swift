import SwiftUI

// MARK: - Goal sheet
//
// What "showing up" means for this circle. Until this existed every circle
// carried a free-text cadence nobody read, and completion was a number that
// crept up by 0.04 on every tap.

struct EditGoalSheet: View {

    let habit: CDHabit
    let onDone: () -> Void

    @State private var type: GoalType = .daily
    @State private var count = 3
    @State private var days: Set<HabitWeekday> = []
    @State private var amount = ""
    @State private var unit = ""
    @State private var didLoad = false

    @Namespace private var segment

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            picker
            detail
            target
            TPPrimaryButton(title: "Save goal", symbol: "target") { save() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 26)
        .onAppear(perform: load)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Goal & frequency")
                .font(TPFont.display(20, .bold))
                .foregroundColor(.tpCream)

            Text(habit.title)
                .font(TPFont.ui(12))
                .foregroundColor(.tpCreamFaint)
        }
    }

    private var picker: some View {
        TPSegmented(
            items: GoalType.allCases,
            selection: $type,
            title: { $0.label },
            namespace: segment
        )
    }

    // MARK: Per-type detail

    @ViewBuilder
    private var detail: some View {
        switch type {
        case .daily:
            Text("Asked for once a day, every day.")
                .font(TPFont.ui(12.5))
                .foregroundColor(.tpCreamDim)

        case .weeklyCount:
            VStack(alignment: .leading, spacing: 10) {
                Text.tpLabel("Times a week")

                HStack(spacing: 7) {
                    ForEach(1...7, id: \.self) { value in
                        Button {
                            TPHaptic.tap()
                            count = value
                        } label: {
                            Text("\(value)")
                                .font(TPFont.figure(14, .heavy))
                                .foregroundColor(count == value ? .tpOnAccent : .tpCreamDim)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(count == value ? habit.accent : Color.tpInkWell)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

        case .weekdays:
            VStack(alignment: .leading, spacing: 10) {
                Text.tpLabel("Which days")

                HStack(spacing: 7) {
                    ForEach(HabitWeekday.allCases) { day in
                        TPSelectableChip(
                            text: day.initial,
                            isSelected: days.contains(day)
                        ) {
                            if days.contains(day) {
                                days.remove(day)
                            } else {
                                days.insert(day)
                            }
                        }
                    }
                }

                if days.isEmpty {
                    Text("Pick at least one day.")
                        .font(TPFont.ui(11.5))
                        .foregroundColor(.tpDanger)
                }
            }
        }
    }

    // MARK: Target amount

    private var target: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text.tpLabel("Target amount · optional")

            HStack(spacing: 10) {
                TPTextField(
                    label: "Amount",
                    placeholder: "0",
                    text: $amount,
                    keyboard: .decimalPad,
                    submitLabel: .done
                )

                TPTextField(
                    label: "Unit",
                    placeholder: "pages",
                    text: $unit,
                    capitalization: .never,
                    submitLabel: .done
                )
                .frame(width: 120)
            }

            Text("Set this when the practice is measured — 500 pages, 5 km — and the recap can total it.")
                .font(TPFont.ui(11.5))
                .foregroundColor(.tpCreamFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Data

    private func load() {
        guard !didLoad else { return }
        didLoad = true

        type = habit.goalType
        count = max(habit.goalTarget, 1)
        days = Set(habit.goalDays)
        if habit.goalAmount > 0 {
            let value = habit.goalAmount
            amount = value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
        }
        unit = habit.goalUnit ?? ""
    }

    private func save() {
        // A weekday goal with nothing ticked has no meaning, so it falls back to
        // the days the goal already had rather than saving an empty schedule.
        let chosen = type == .weekdays
            ? (days.isEmpty ? habit.goalDays : Array(days))
            : []

        HabitService.setGoal(
            habit,
            type: type,
            count: count,
            weekdays: chosen,
            amount: Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0,
            unit: unit
        )

        TPHaptic.success()
        tpToast("Goal saved", tone: .success, symbol: "target")
        onDone()
    }
}
