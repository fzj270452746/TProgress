import SwiftUI
import CoreData

// MARK: - Questions
//
// One question, shared by a circle, for a week.
//
// The hardest part of keeping a log is having something to say, and a shared
// question answers that without putting a scoreboard in the middle: everyone
// sits with the same sentence for the same seven days, and what each of them
// writes under it is their own.
//
// The built-in pool is grouped by the categories the circles already carry, so
// a circle nobody has touched still has something worth answering. A circle can
// add its own, or replace the built-ins entirely.

struct PromptLibraryView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var circles: [CDHabit] = []
    @State private var editing: CDHabit?
    @State private var hasLoaded = false

    private let accent = Color.tpLilac

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "Questions",
                subtitle: "This week's question, and your own",
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

                        VStack(spacing: 12) {
                            ForEach(circles, id: \.objectID) { habit in
                                card(habit)
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
                PromptEditorSheet(habit: habit) {
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
        Text("Built-in questions come with the app, matched to what each circle is for. Add your own to replace them or to sit alongside them.")
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

    // MARK: Card

    private func card(_ habit: CDHabit) -> some View {
        let question = PromptService.current(for: habit)

        return VStack(alignment: .leading, spacing: 14) {
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

                    Text(habit.categoryLabel)
                        .font(TPFont.ui(11.5))
                        .foregroundColor(.tpCreamFaint)
                }

                Spacer(minLength: 6)

                if PromptService.isCustomised(habit) {
                    TPTag(text: habit.promptReplacesBuiltIns ? "Yours only" : "Yours added", color: accent)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text.tpLabel("This week")

                Text(question)
                    .font(TPFont.display(16, .bold))
                    .foregroundColor(.tpCream)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }

            HStack(spacing: 9) {
                Button {
                    answer(habit, question: question)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11, weight: .bold))
                        Text("Answer it")
                            .font(TPFont.ui(12.5, .semibold))
                    }
                    .foregroundColor(.tpOnAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(habit.accent)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    TPHaptic.tap()
                    editing = habit
                } label: {
                    Text("Your own")
                        .font(TPFont.ui(12.5, .semibold))
                        .foregroundColor(.tpCreamDim)
                        .frame(width: 96)
                        .frame(height: 40)
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
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
    }

    // MARK: Actions

    private func answer(_ habit: CDHabit, question: String) {
        session.withAuth(prompt: "Sign in to answer.") {
            guard let id = habit.id else { return }
            router.push(.circle(id))
            tpToast("Answer it from the circle, or when you log", tone: .neutral, symbol: "questionmark.bubble")
        }
    }

    // MARK: Empty

    private var signedOut: some View {
        TPEmptyState(
            symbol: "questionmark.bubble",
            title: "Sign in to see this",
            message: "Questions belong to the circles you have joined.",
            actionTitle: "Sign in",
            action: { session.presentAuth(prompt: "Sign in to see your questions.") },
            accent: accent
        )
    }

    private var empty: some View {
        TPEmptyState(
            symbol: "questionmark.bubble",
            title: "No circles yet",
            message: "Join a circle and it gets a question to sit with each week.",
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
// Shared with the circle's own menu, so a circle's questions can be edited where
// the circle is.

struct PromptEditorSheet: View {

    let habit: CDHabit
    let onDone: () -> Void

    @State private var text = ""
    @State private var replaces = true
    @State private var didLoad = false

    @Namespace private var segment

    private struct Mode: Hashable, Identifiable {
        let id: String
        let label: String
        let replaces: Bool
    }

    private let modes: [Mode] = [
        Mode(id: "replace", label: "Replace", replaces: true),
        Mode(id: "extend", label: "Add to", replaces: false),
    ]

    private var selection: Binding<Mode> {
        Binding(
            get: { modes.first { $0.replaces == replaces } ?? modes[0] },
            set: { replaces = $0.replaces }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            picker

            VStack(alignment: .leading, spacing: 8) {
                Text.tpLabel("Your questions")

                TPTextEditor(
                    text: $text,
                    placeholder: "One question per line.\nWhat did you keep?\nWhere did it resist you?",
                    height: 150,
                    maxLength: 800
                )

                Text("One per line. The circle sees one a week, in this order, cycling on.")
                    .font(TPFont.ui(11.5))
                    .foregroundColor(.tpCreamFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                TPPrimaryButton(title: "Save questions", symbol: "questionmark.bubble") {
                    save()
                }

                if habit.hasCustomPrompts {
                    TPQuietButton(title: "Back to the built-in set", tint: .tpDanger) {
                        PromptService.clearCustom(habit)
                        TPHaptic.tap()
                        tpToast("Back to the built-in questions", tone: .neutral, symbol: "arrow.uturn.backward")
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
            Text("Your own questions")
                .font(TPFont.display(20, .bold))
                .foregroundColor(.tpCream)

            Text(habit.title)
                .font(TPFont.ui(12))
                .foregroundColor(.tpCreamFaint)
        }
    }

    private var picker: some View {
        TPSegmented(items: modes, selection: selection, title: \.label, namespace: segment)
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true

        text = habit.customPrompts.joined(separator: "\n")
        replaces = habit.hasCustomPrompts ? habit.promptReplacesBuiltIns : true
    }

    private func save() {
        let questions = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !questions.isEmpty else {
            tpToast("Write at least one question", tone: .warning, symbol: "exclamationmark")
            return
        }

        PromptService.setCustom(habit, prompts: questions, replacesBuiltIns: replaces)
        TPHaptic.success()
        tpToast("Questions saved", tone: .success, symbol: "questionmark.bubble")
        onDone()
    }
}
