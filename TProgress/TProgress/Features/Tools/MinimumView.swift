import SwiftUI
import CoreData

// MARK: - Minimums
//
// The smallest version of a practice that still counts.
//
// Not a target — the target is what an honest day looks like. This is the floor
// under it, for the days when the full thing was never going to happen and doing
// nothing was the alternative. Doing only the minimum keeps the run alive
// exactly as a full session would, which is the point of having defined one.

struct MinimumView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var circles: [CDHabit] = []
    @State private var editing: CDHabit?
    @State private var hasLoaded = false

    private let accent = Color.tpMint

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "Minimums",
                subtitle: "What still counts on a bad day",
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
        .tpSheet(isPresented: editingBinding) {
            if let habit = editing {
                MinimumEditorSheet(habit: habit) {
                    editing = nil
                    reload()
                }
            }
        }
    }

    private var editingBinding: Binding<Bool> {
        Binding(
            get: { editing != nil },
            set: { if !$0 { editing = nil } }
        )
    }

    // MARK: Intro

    private var intro: some View {
        Text("A minimum is the version you would still call doing it — out the door for five minutes, one page, a single scale. Logging only that counts the same as any other day, because the alternative was nothing.")
            .font(TPFont.ui(13))
            .foregroundColor(.tpCreamDim)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
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
        VStack(alignment: .leading, spacing: 12) {
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

                    Text(habit.hasMinimum ? habit.minimumText : "No minimum set")
                        .font(TPFont.ui(12))
                        .foregroundColor(habit.hasMinimum ? .tpCreamDim : .tpCreamFaint)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                if habit.hasMinimum {
                    TPTag(text: "Set", color: accent)
                }
            }

            HStack(spacing: 9) {
                if habit.hasMinimum {
                    Button {
                        logMinimum(habit)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 11, weight: .bold))
                            Text(habit.todayChecked ? "Logged today" : "Do only this")
                                .font(TPFont.ui(12.5, .semibold))
                        }
                        .foregroundColor(habit.todayChecked ? .tpCreamFaint : .tpOnAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(habit.todayChecked ? Color.tpInkWell : habit.accent)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(habit.todayChecked)
                }

                Button {
                    TPHaptic.tap()
                    editing = habit
                } label: {
                    Text(habit.hasMinimum ? "Edit" : "Set a minimum")
                        .font(TPFont.ui(12.5, .semibold))
                        .foregroundColor(.tpCreamDim)
                        .frame(maxWidth: habit.hasMinimum ? 74 : .infinity)
                        .frame(height: 40)
                        .padding(.horizontal, habit.hasMinimum ? 14 : 0)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(Color.tpInkWell)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
    }

    // MARK: Actions

    private func logMinimum(_ habit: CDHabit) {
        session.withAuth(prompt: "Sign in to log today.") {
            guard HabitService.logMinimum(habit) != nil else { return }
            TPHaptic.success()
            tpToast("Minimum logged — that counts", tone: .success, symbol: "arrow.down.circle")
            RefreshSignal.shared.bumpPractice()
            reload()
        }
    }

    // MARK: Empty

    private var signedOut: some View {
        TPEmptyState(
            symbol: "arrow.down.circle",
            title: "Sign in to set this up",
            message: "Minimums belong to the circles you have joined.",
            actionTitle: "Sign in",
            action: { session.presentAuth(prompt: "Sign in to set a minimum.") },
            accent: accent
        )
    }

    private var empty: some View {
        TPEmptyState(
            symbol: "arrow.down.circle",
            title: "No circles yet",
            message: "Join a circle and you can decide what still counts on the days that go wrong.",
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
        withAnimation(TPMotion.gentle) {
            circles = StatsService.joinedCircles()
        }
    }
}

// MARK: - Editor
//
// Shared with the circle's own menu, so the decision can be made where the
// practice is rather than only from the Tools hub.

struct MinimumEditorSheet: View {

    let habit: CDHabit
    let onDone: () -> Void

    @State private var label = ""
    @State private var amount = ""
    @State private var unit = ""
    @State private var didLoad = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            TPTextField(
                label: "Say it in a line",
                placeholder: "Out the door for five minutes",
                text: $label,
                submitLabel: .next
            )

            VStack(alignment: .leading, spacing: 10) {
                Text.tpLabel("Amount · optional")

                HStack(spacing: 10) {
                    TPTextField(
                        label: "Amount",
                        placeholder: "5",
                        text: $amount,
                        keyboard: .decimalPad,
                        submitLabel: .done
                    )

                    TPTextField(
                        label: "Unit",
                        placeholder: "min",
                        text: $unit,
                        capitalization: .never,
                        submitLabel: .done
                    )
                    .frame(width: 120)
                }

                Text("Leave the amount out when the minimum is not a number — \"one page\" is a perfectly good floor.")
                    .font(TPFont.ui(11.5))
                    .foregroundColor(.tpCreamFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                TPPrimaryButton(title: "Save minimum", symbol: "arrow.down.circle") {
                    save()
                }

                if habit.hasMinimum {
                    TPQuietButton(title: "Remove this minimum", tint: .tpDanger) {
                        HabitService.clearMinimum(habit)
                        TPHaptic.tap()
                        tpToast("Minimum removed", tone: .neutral, symbol: "arrow.uturn.backward")
                        onDone()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 26)
        .onAppear(perform: load)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("The smallest version")
                .font(TPFont.display(20, .bold))
                .foregroundColor(.tpCream)

            Text(habit.title)
                .font(TPFont.ui(12))
                .foregroundColor(.tpCreamFaint)
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true

        label = habit.minimumText
        if habit.minimumAmount > 0 {
            let value = habit.minimumAmount
            amount = value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
        }
        unit = habit.minimumUnit ?? ""
    }

    private func save() {
        let normalised = amount.replacingOccurrences(of: ",", with: ".")
        HabitService.setMinimum(
            habit,
            label: label,
            amount: Double(normalised) ?? 0,
            unit: unit
        )
        TPHaptic.success()
        tpToast("Minimum saved", tone: .success, symbol: "arrow.down.circle")
        onDone()
    }
}
