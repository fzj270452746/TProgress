import SwiftUI
import CoreData

// MARK: - Focus timer
//
// Sitting with one circle and letting the clock do the accounting. The only
// screen in the app built around a number that keeps moving.

struct FocusTimerView: View {

    let habit: CDHabit

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var timer = FocusTimerService.shared

    @State private var target = 25
    @State private var note = ""
    @State private var notesOpen = false
    @State private var confirmingDiscard = false

    private var isThisCircle: Bool { timer.habit?.objectID == habit.objectID }
    private var isActiveHere: Bool { isThisCircle && timer.habit != nil }

    private static let targets = [10, 25, 45, 60]

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: habit.title,
                subtitle: isActiveHere ? (timer.isRunning ? "Running" : "Paused") : "Focus",
                onBack: { leave() }
            )

            ScrollView {
                VStack(spacing: 22) {
                    dial
                    targetPicker
                    controls
                    if isActiveHere { noteSection }
                    hint
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
                TPHalo(color: habit.accent, spread: 1.05).offset(y: -210)
                TPGrain(opacity: 0.04)
            }
            .ignoresSafeArea()
        )
        .alert("Leave without logging?", isPresented: $confirmingDiscard) {
            Button("Discard run", role: .destructive) {
                timer.cancel()
                router.pop()
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("The clock is still going. Leaving now throws the session away.")
        }
    }

    // MARK: Dial

    private var dial: some View {
        ZStack {
            TPRing(
                progress: isActiveHere ? timer.progress(toward: target) : 0,
                size: 248,
                lineWidth: 14,
                colors: [habit.accent, habit.accent.opacity(0.45)],
                trackColor: .tpInkWell,
                showsTicks: false
            )

            VStack(spacing: 6) {
                Text(isActiveHere ? timer.clockLabel : "0:00")
                    .font(TPFont.figure(46, .heavy))
                    .foregroundColor(.tpCream)
                    .monospacedDigit()

                Text.tpLabel(
                    isActiveHere ? "of \(target) min" : "ready",
                    size: 9.5,
                    tracking: 1.4
                )
            }
        }
        .padding(.top, 4)
    }

    // MARK: Target

    private var targetPicker: some View {
        VStack(spacing: 10) {
            Text.tpLabel("Session length")

            HStack(spacing: 8) {
                ForEach(Self.targets, id: \.self) { value in
                    Button {
                        TPHaptic.tap()
                        target = value
                    } label: {
                        Text("\(value)m")
                            .font(TPFont.figure(13, .bold))
                            .foregroundColor(target == value ? .tpOnAccent : .tpCreamDim)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(target == value ? habit.accent : Color.tpInkWell)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isActiveHere)
                }
            }
            .opacity(isActiveHere ? 0.5 : 1)
        }
    }

    // MARK: Controls

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 10) {
            switch (isActiveHere, timer.isRunning) {
            case (false, _):
                TPPrimaryButton(title: "Start focus", symbol: "play.fill") {
                    session.withAuth(prompt: "Sign in to log a session.") {
                        timer.start(habit)
                    }
                }

            case (true, true):
                TPPrimaryButton(title: "Pause", symbol: "pause.fill") {
                    timer.pause()
                }
                finishButton

            case (true, false):
                TPPrimaryButton(title: "Resume", symbol: "play.fill") {
                    timer.resume()
                }
                finishButton

                TPQuietButton(title: "Discard this run", tint: .tpDanger) {
                    timer.cancel()
                }
            }
        }
    }

    private var finishButton: some View {
        TPOutlineButton(title: "Finish & log \(timer.loggedMinutes) min", symbol: "checkmark.circle") {
            session.withAuth(prompt: "Sign in to log a session.") {
                timer.finish(note: note)
                TPHaptic.success()
                tpToast("Logged \(timer.loggedMinutes) min", tone: .success, symbol: "timer")
                RefreshSignal.shared.bumpPractice()
                router.pop()
            }
        }
    }

    // MARK: Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(TPMotion.gentle) { notesOpen.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: notesOpen ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(notesOpen ? "Hide note" : "Add a note")
                        .font(TPFont.ui(12.5, .semibold))
                }
                .foregroundColor(.tpCreamFaint)
            }
            .buttonStyle(.plain)

            if notesOpen {
                TPTextEditor(
                    text: $note,
                    placeholder: "What did the time actually go on?",
                    height: 96,
                    maxLength: 240
                )
            }
        }
    }

    private var hint: some View {
        Text("The clock only runs while the app is open. That is a limit of what this build supports, not a choice — the recorded time is real either way.")
            .font(TPFont.ui(11.5))
            .foregroundColor(.tpCreamFaint)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
    }

    // MARK: Leaving

    private func leave() {
        if isActiveHere && timer.isRunning {
            confirmingDiscard = true
        } else {
            router.pop()
        }
    }
}
