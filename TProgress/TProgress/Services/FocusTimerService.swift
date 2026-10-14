import Foundation
import Combine
import CoreData

// MARK: - Focus timer
//
// A real clock, so `durationMinutes` has a real source. Before this the only
// things that ever wrote a duration were the seed data and a number field in
// the compose sheet.
//
// The run is banked in `UserDefaults` so it survives the app being backgrounded
// and killed. That is deliberately the whole of the persistence: a Live Activity
// would need iOS 16.1 and this app supports 15, so the timer lives in the app
// and says so.

final class FocusTimerService: ObservableObject {

    static let shared = FocusTimerService()

    @Published private(set) var habit: CDHabit?
    @Published private(set) var elapsed: Int = 0
    @Published private(set) var isRunning = false

    /// Seconds finished on previous runs of this session, before any pause.
    private var banked: Int = 0

    /// When the current run began, nil while paused.
    private var runStartedAt: Date?

    private var ticker: AnyCancellable?

    private let defaults = UserDefaults.standard
    private enum Key {
        static let habit = "tp.focus.habitID"
        static let started = "tp.focus.runStartedAt"
        static let banked = "tp.focus.banked"
    }

    private init() {
        restore()
    }

    // MARK: - Reading

    var isIdle: Bool { habit == nil }

    /// "12:04" — minutes and seconds, hours only once they are earned.
    var clockLabel: String {
        let total = max(elapsed, 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    /// Minutes to record — a session counts from the first minute.
    var loggedMinutes: Int { max(1, Int((Double(elapsed) / 60).rounded())) }

    func progress(toward target: Int) -> Double {
        guard target > 0 else { return 0 }
        return min(1, Double(elapsed) / Double(target * 60))
    }

    // MARK: - Control

    func start(_ habit: CDHabit, carryingOver: Int = 0) {
        if self.habit?.objectID != habit.objectID {
            banked = carryingOver
            elapsed = banked
        }
        self.habit = habit
        runStartedAt = Date()
        isRunning = true
        persist()
        beginTicking()
        TPHaptic.tap()
    }

    func pause() {
        guard isRunning else { return }
        banked = elapsed
        runStartedAt = nil
        isRunning = false
        persist()
        stopTicking()
        TPHaptic.tap()
    }

    func resume() {
        guard habit != nil, !isRunning else { return }
        runStartedAt = Date()
        isRunning = true
        persist()
        beginTicking()
        TPHaptic.tap()
    }

    /// Abandons the run without writing anything to the log.
    func cancel() {
        stopTicking()
        habit = nil
        runStartedAt = nil
        banked = 0
        elapsed = 0
        isRunning = false
        clearPersisted()
    }

    /// Ends the run and records it as the day's check-in.
    @discardableResult
    func finish(note: String) -> CDCheckIn? {
        guard let habit else { return nil }
        let minutes = loggedMinutes

        stopTicking()
        cancel()

        let entry = HabitService.logCheckIn(
            habit,
            amount: Double(minutes),
            unit: "min",
            minutes: minutes,
            note: note
        )
        return entry
    }

    // MARK: - Ticking

    private func beginTicking() {
        stopTicking()
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }

    private func tick() {
        guard let runStartedAt else { return }
        elapsed = banked + Int(Date().timeIntervalSince(runStartedAt))
    }

    // MARK: - Persistence

    private func persist() {
        defaults.set(habit?.id?.uuidString, forKey: Key.habit)
        defaults.set(runStartedAt, forKey: Key.started)
        defaults.set(banked, forKey: Key.banked)
    }

    private func clearPersisted() {
        defaults.removeObject(forKey: Key.habit)
        defaults.removeObject(forKey: Key.started)
        defaults.removeObject(forKey: Key.banked)
    }

    /// Rebuilds a run that was in flight when the process ended. A run that was
    /// paused comes back paused; one that was running keeps counting from when
    /// it started, because the clock did not stop just because the app did.
    private func restore() {
        guard let raw = defaults.string(forKey: Key.habit),
              let id = UUID(uuidString: raw),
              let circle = TPStore.habit(id) else { return }

        habit = circle
        banked = defaults.integer(forKey: Key.banked)
        elapsed = banked

        if let started = defaults.object(forKey: Key.started) as? Date {
            runStartedAt = started
            isRunning = true
            tick()
            beginTicking()
        } else {
            isRunning = false
        }
    }
}
