import SwiftUI
import CoreData

// MARK: - Planned rest
//
// A day off decided in advance.
//
// A rest keeps the run alive and costs nothing, which is exactly why it can only
// be claimed ahead of time. A rest declared afterwards is not a plan, it is a
// story — and the value of this log is that it does not contain any. That single
// rule is what separates this from a freeze card: the card buys a day back after
// the fact and is scarce, while this is free and therefore has to be honest.

struct PlannedRestView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var circles: [CDHabit] = []
    @State private var tick = 0
    @State private var hasLoaded = false

    private let accent = Color.tpSky

    private var calendar: Calendar { Calendar.current }
    private var today: Date { calendar.startOfDay(for: Date()) }
    private var tomorrow: Date { calendar.date(byAdding: .day, value: 1, to: today) ?? today }

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "Planned rest",
                subtitle: "Declared before, never after",
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

                        VStack(spacing: 10) {
                            ForEach(circles, id: \.objectID) { habit in
                                row(habit)
                            }
                        }

                        footer
                    }
                }
                .padding(.horizontal, TPMetric.gutter)
                .padding(.bottom, 50)
            }
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
            Text("A rest is part of the plan.")
                .font(TPFont.display(17, .bold))
                .foregroundColor(.tpCream)

            Text("It keeps the run alive and spends nothing. It also has to be said in advance, because that is the only version of it that is true — and it has to come from you, because that is the only version that is a plan.")
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

    // MARK: Row

    private func row(_ habit: CDHabit) -> some View {
        let restToday = HabitService.hasRested(habit, on: today)
        let restTomorrow = HabitService.hasRested(habit, on: tomorrow)
        let doneToday = habit.todayChecked

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(habit.accent.opacity(0.15))
                        .frame(width: 36, height: 36)

                    TPIcon(
                        name: habit.iconAssetName,
                        fallbackSymbol: habit.symbol,
                        size: 15,
                        tint: habit.accent
                    )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.title)
                        .font(TPFont.ui(14, .semibold))
                        .foregroundColor(.tpCream)
                        .lineLimit(1)

                    Text(status(restToday: restToday, restTomorrow: restTomorrow, doneToday: doneToday))
                        .font(TPFont.ui(12))
                        .foregroundColor(restToday || restTomorrow ? accent : .tpCreamFaint)
                }

                Spacer(minLength: 6)

                if restToday {
                    TPTag(text: "Resting", color: accent)
                }
            }

            if restToday {
                Button {
                    cancel(habit, on: today)
                } label: {
                    Text("Undo today's rest")
                        .font(TPFont.ui(12.5, .semibold))
                        .foregroundColor(.tpCreamDim)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(Color.tpInkWell)
                        )
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 9) {
                    actionButton(
                        title: "Rest today",
                        enabled: !doneToday && !restTomorrow
                    ) {
                        declare(habit, on: today)
                    }

                    actionButton(
                        title: restTomorrow ? "Undo tomorrow" : "Rest tomorrow",
                        enabled: true
                    ) {
                        if restTomorrow {
                            cancel(habit, on: tomorrow)
                        } else {
                            declare(habit, on: tomorrow)
                        }
                    }
                }
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(restToday || restTomorrow ? accent.opacity(0.34) : Color.tpLine, lineWidth: 1)
        )
    }

    private func actionButton(
        title: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(TPFont.ui(12.5, .semibold))
                .foregroundColor(enabled ? .tpCreamDim : .tpCreamFaint.opacity(0.6))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.tpInkWell)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func status(restToday: Bool, restTomorrow: Bool, doneToday: Bool) -> String {
        if restToday { return "Today is set aside." }
        if restTomorrow { return "Tomorrow is set aside." }
        if doneToday { return "Already logged today." }
        return "Nothing set aside."
    }

    // MARK: Footer

    private var footer: some View {
        Text("A day already logged cannot be rested, and a rest cannot be backdated. Both rules exist for the same reason: the log is only worth reading if it cannot be edited into something kinder.")
            .font(TPFont.ui(11.5))
            .foregroundColor(.tpCreamFaint)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }

    // MARK: Actions

    private func declare(_ habit: CDHabit, on day: Date) {
        session.withAuth(prompt: "Sign in to set a rest day.") {
            guard HabitService.declareRest(habit, on: day) else {
                tpToast("That day cannot be rested", tone: .warning, symbol: "exclamationmark")
                return
            }
            TPHaptic.success()
            tpToast(day == today ? "Today is set aside" : "Tomorrow is set aside",
                    tone: .success, symbol: "moon.zzz")
            RefreshSignal.shared.bumpPractice()
            reload()
        }
    }

    private func cancel(_ habit: CDHabit, on day: Date) {
        session.withAuth(prompt: "Sign in to change this.") {
            HabitService.cancelRest(habit, on: day)
            TPHaptic.tap()
            tpToast("Rest removed", tone: .neutral, symbol: "arrow.uturn.backward")
            RefreshSignal.shared.bumpPractice()
            reload()
        }
    }

    // MARK: Empty

    private var signedOut: some View {
        TPEmptyState(
            symbol: "moon.zzz",
            title: "Sign in to plan a rest",
            message: "Rest days belong to the circles you have joined.",
            actionTitle: "Sign in",
            action: { session.presentAuth(prompt: "Sign in to plan a rest.") },
            accent: accent
        )
    }

    private var empty: some View {
        TPEmptyState(
            symbol: "moon.zzz",
            title: "No circles yet",
            message: "Join a circle and you can set a day aside without breaking the run.",
            actionTitle: "Browse circles",
            action: { router.select(.circles) },
            accent: accent
        )
    }

    // MARK: Data

    private func reload() {
        guard session.isSignedIn else {
            circles = []
            return
        }
        // `tick` is read here so the row rebuilds when midnight has moved the
        // rest window on, rather than holding yesterday's answer.
        _ = tick
        withAnimation(TPMotion.gentle) {
            circles = StatsService.joinedCircles()
        }
    }
}
