import SwiftUI
import CoreData

// MARK: - Fill in a day
//
// Writing up a day that has already gone.
//
// The window is deliberately short: a week of hindsight is a spreadsheet, three
// days is a memory. And a day filled in afterwards never lengthens a run — it
// makes the record complete, it does not rewrite it. The page says that plainly,
// because a rule the writer does not know about is a rule that feels like a bug.

struct BackfillView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var circles: [CDHabit] = []
    @State private var habit: CDHabit?
    @State private var day: Date?
    @State private var amount = ""
    @State private var unit = ""
    @State private var minutes = ""
    @State private var note = ""
    @State private var hasLoaded = false

    private let accent = Color.tpSun

    private var openDays: [Date] {
        guard let habit else { return [] }
        return HabitService.backfillableDays(for: habit)
    }

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "Fill in a day",
                subtitle: "Up to \(HabitService.backfillWindow) days back",
                onBack: { router.pop() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !session.isSignedIn {
                        signedOut
                    } else if circles.isEmpty {
                        empty
                    } else {
                        intro
                        circlePicker
                        dayPicker
                        if habit != nil && day != nil {
                            form
                        }
                    }
                }
                .padding(.horizontal, TPMetric.gutter)
                .padding(.bottom, 50)
            }
            .tpDismissKeyboardOnTap()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                TPBackdropView(style: .deep)
                TPHalo(color: accent, spread: 1.05)
                    .offset(y: -220)
                TPGrain(opacity: 0.04)
            }
            .ignoresSafeArea()
        )
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            reload()
        }
        .onChange(of: refresh.practice) { _ in reload() }
    }

    // MARK: Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("For the days you forgot to write down.")
                .font(TPFont.display(17, .bold))
                .foregroundColor(.tpCream)

            Text("Filling a day in makes the record complete. It does not rewrite the run — a day you claimed later is a day you claimed later, and the streak knows the difference.")
                .font(TPFont.ui(13))
                .foregroundColor(.tpCreamDim)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(accent.opacity(0.24), lineWidth: 1)
        )
    }

    // MARK: Picker

    private var circlePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text.tpLabel("Which circle")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(circles, id: \.objectID) { candidate in
                        TPSelectableChip(
                            text: candidate.title,
                            isSelected: candidate.objectID == habit?.objectID,
                            symbol: candidate.symbol,
                            assetName: candidate.iconAssetName
                        ) {
                            select(candidate)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    @ViewBuilder
    private var dayPicker: some View {
        if habit != nil {
            VStack(alignment: .leading, spacing: 10) {
                Text.tpLabel("Which day")

                if openDays.isEmpty {
                    Text("Nothing left to fill in. Every day in the window is already on the log.")
                        .font(TPFont.ui(12.5))
                        .foregroundColor(.tpCreamFaint)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.tpInkRaised)
                        )
                } else {
                    HStack(spacing: 8) {
                        ForEach(openDays, id: \.self) { candidate in
                            Button {
                                TPHaptic.tap()
                                day = candidate
                            } label: {
                                VStack(spacing: 2) {
                                    Text(weekday(candidate))
                                        .font(TPFont.ui(11, .semibold))
                                    Text(dayNumber(candidate))
                                        .font(TPFont.figure(14, .bold))
                                }
                                .foregroundColor(isSelected(candidate) ? .tpOnAccent : .tpCreamDim)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(isSelected(candidate) ? (habit?.accent ?? accent) : Color.tpInkWell)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            TPFadeRule()

            VStack(alignment: .leading, spacing: 10) {
                Text.tpLabel("What happened")

                HStack(spacing: 10) {
                    TPTextField(
                        label: "Amount",
                        placeholder: "0",
                        text: $amount,
                        keyboard: .decimalPad,
                        submitLabel: .next
                    )

                    TPTextField(
                        label: "Unit",
                        placeholder: "session",
                        text: $unit,
                        capitalization: .never,
                        submitLabel: .next
                    )
                    .frame(width: 120)
                }
            }

            TPTextField(
                label: "Time on it · optional",
                placeholder: "Optional",
                text: $minutes,
                keyboard: .numberPad,
                submitLabel: .done,
                symbol: "timer"
            )

            VStack(alignment: .leading, spacing: 8) {
                Text.tpLabel("A line about it")
                TPTextEditor(
                    text: $note,
                    placeholder: "What actually happened?",
                    height: 92,
                    maxLength: 240
                )
            }

            TPPrimaryButton(title: "Add to \(dayLabel)", symbol: "clock.arrow.circlepath") {
                save()
            }
        }
    }

    // MARK: Actions

    private func select(_ candidate: CDHabit) {
        habit = candidate
        amount = ""
        minutes = ""
        note = ""
        unit = candidate.category == "Reading" ? "pages" : (candidate.category == "Movement" ? "km" : "session")
        // The window is rebuilt every time a circle is picked, so a day that
        // closed at midnight is never offered.
        day = HabitService.backfillableDays(for: candidate).first
    }

    private func save() {
        guard let habit, let day else { return }

        session.withAuth(prompt: "Sign in to fill in a day.") {
            let normalised = amount.replacingOccurrences(of: ",", with: ".")
            let value = Double(normalised) ?? (unit == "session" ? 1 : 0)

            guard HabitService.logBackfill(
                habit,
                on: day,
                amount: value,
                unit: unit,
                minutes: Int(minutes) ?? 0,
                note: note
            ) != nil else {
                tpToast("That day is no longer open", tone: .warning, symbol: "exclamationmark")
                reload()
                return
            }

            TPHaptic.success()
            tpToast("Added to \(dayLabel). It won't lengthen your streak.",
                    tone: .success, symbol: "clock.arrow.circlepath")
            RefreshSignal.shared.bumpPractice()

            amount = ""
            minutes = ""
            note = ""
            reload()
        }
    }

    // MARK: Empty

    private var signedOut: some View {
        TPEmptyState(
            symbol: "clock.arrow.circlepath",
            title: "Sign in to fill in a day",
            message: "This writes to your own log.",
            actionTitle: "Sign in",
            action: { session.presentAuth(prompt: "Sign in to fill in a day.") },
            accent: accent
        )
    }

    private var empty: some View {
        TPEmptyState(
            symbol: "clock.arrow.circlepath",
            title: "No circles to fill in",
            message: "Join a circle and this can catch up the days you missed writing down.",
            actionTitle: "Browse circles",
            action: { router.select(.circles) },
            accent: accent
        )
    }

    // MARK: Data

    private func reload() {
        guard session.isSignedIn else {
            circles = []
            habit = nil
            return
        }

        let joined = StatsService.joinedCircles()
        circles = joined

        // Keeps the current choice alive across a reload, and drops it only when
        // the circle is genuinely gone.
        if let current = habit, !joined.contains(where: { $0.objectID == current.objectID }) {
            habit = nil
            day = nil
        } else if habit == nil {
            if let first = joined.first { select(first) }
        } else if let current = habit {
            // A day may have fallen out of the window since it was chosen.
            let open = HabitService.backfillableDays(for: current)
            if let chosen = day, !open.contains(chosen) {
                day = open.first
            }
        }
    }

    // MARK: Formatting

    private func isSelected(_ date: Date) -> Bool {
        guard let day else { return false }
        return Calendar.current.isDate(day, inSameDayAs: date)
    }

    private var dayLabel: String {
        guard let day else { return "that day" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: day)
    }

    private func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func dayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}
