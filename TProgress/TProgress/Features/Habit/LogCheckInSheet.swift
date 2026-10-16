import SwiftUI

// MARK: - Check-in sheet
//
// The deliberate path for a day: how much, for how long, and a line about it.
// The cheap path is `HabitService.quickLog` — this is what opens when there is
// something to say, or when a day already logged needs describing.
//
// Before this existed the app wrote `amountValue = 1`, `amountUnit = "session"`
// and an empty note on every check-in from three different views, so the log
// could never say anything about the practice it recorded.

struct LogCheckInSheet: View {

    let habit: CDHabit

    /// The question this entry is answering, when it came from one. Shown above
    /// the note so the line has something to answer — which is the whole of the
    /// feature: the question does the work, and no extra chrome is needed.
    var prompt: String? = nil

    let onDone: () -> Void

    @State private var amount = ""
    @State private var unit = "session"
    @State private var minutes = ""
    @State private var note = ""
    @State private var didLoad = false

    private var existing: CDCheckIn? { HabitService.todayCheckIn(for: habit) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if let prompt { promptCard(prompt) }
            amountSection
            minutesSection
            noteSection
            actions
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 26)
        .onAppear(perform: load)
    }

    // MARK: Prompt

    private func promptCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text.tpLabel("This week's question")

            Text(text)
                .font(TPFont.display(15, .bold))
                .foregroundColor(.tpCream)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(habit.accent.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(habit.accent.opacity(0.30), lineWidth: 1)
        )
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(habit.accent.opacity(0.16))
                    .frame(width: 44, height: 44)

                TPIcon(
                    name: habit.iconAssetName,
                    fallbackSymbol: habit.symbol,
                    size: 19,
                    tint: habit.accent
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(existing == nil ? "Log today" : "Today's log")
                    .font(TPFont.display(20, .bold))
                    .foregroundColor(.tpCream)

                Text("\(habit.title) · \(habit.goalLabel)")
                    .font(TPFont.ui(12))
                    .foregroundColor(.tpCreamFaint)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if habit.streak > 0 {
                TPTag(text: "\(habit.streak) day", color: .tpSun)
            }
        }
    }

    // MARK: Amount

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TPTextField(
                label: "How much",
                placeholder: "1",
                text: $amount,
                keyboard: .decimalPad,
                submitLabel: .next
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(unitOptions, id: \.self) { option in
                        TPSelectableChip(text: option, isSelected: unit == option) {
                            unit = option
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Minutes

    private var minutesSection: some View {
        TPTextField(
            label: "Time on it",
            placeholder: "Optional",
            text: $minutes,
            keyboard: .numberPad,
            submitLabel: .done,
            symbol: "timer"
        )
    }

    // MARK: Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text.tpLabel("A line about it")

            TPTextEditor(
                text: $note,
                placeholder: "What actually happened?",
                height: 92,
                maxLength: 240
            )
        }
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 10) {
            TPPrimaryButton(
                title: existing == nil ? "Log today" : "Save changes",
                symbol: existing == nil ? "plus.circle.fill" : "checkmark.circle.fill"
            ) {
                save()
            }

            // The floor, offered where the decision is actually being made. A
            // day that only got the minimum counts exactly as a full one does.
            if existing == nil && habit.hasMinimum {
                TPOutlineButton(title: "Only the minimum", symbol: "arrow.down.circle") {
                    logMinimum()
                }
            }

            if existing != nil {
                TPQuietButton(title: "Remove today's log", tint: .tpDanger) {
                    remove()
                }
            }
        }
    }

    // MARK: Data

    /// The unit a circle is naturally measured in, so the sheet opens on the
    /// one most people would pick.
    private var defaultUnit: String {
        switch habit.category {
        case "Reading":  return "pages"
        case "Movement": return "km"
        default:         return "session"
        }
    }

    private var unitOptions: [String] {
        let all = [defaultUnit, "session", "min", "pages", "km", unit]
        return all.reduce(into: [String]()) { result, value in
            if !result.contains(value) { result.append(value) }
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true

        guard let entry = existing else {
            unit = defaultUnit
            amount = defaultUnit == "session" ? "1" : ""
            return
        }

        let value = entry.amountValue
        amount = value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
        unit = entry.amountUnit ?? defaultUnit
        minutes = entry.durationMinutes > 0 ? String(entry.durationMinutes) : ""
        note = entry.noteText
    }

    private func save() {
        let normalised = amount.replacingOccurrences(of: ",", with: ".")
        let value = Double(normalised) ?? (unit == "session" ? 1 : 0)
        let time = Int(minutes) ?? 0

        if let entry = existing {
            HabitService.update(entry, amount: value, unit: unit, minutes: time, note: note, prompt: prompt)
        } else {
            HabitService.logCheckIn(habit, amount: value, unit: unit, minutes: time, note: note, prompt: prompt)
        }

        TPHaptic.success()
        tpToast(
            existing == nil ? "Logged for today" : "Saved",
            tone: .success,
            symbol: "checkmark"
        )
        onDone()
    }

    private func remove() {
        HabitService.removeToday(habit)
        TPHaptic.tap()
        tpToast("Removed today's log", tone: .neutral, symbol: "arrow.uturn.backward")
        onDone()
    }

    /// The smallest version, logged without filling anything in. Kept separate
    /// from `save()` on purpose: this path is meant to cost one tap, and a form
    /// standing between someone and the floor is the form defeating the floor.
    private func logMinimum() {
        guard HabitService.logMinimum(habit) != nil else { return }
        TPHaptic.success()
        tpToast("Minimum logged — that counts", tone: .success, symbol: "arrow.down.circle")
        onDone()
    }
}
