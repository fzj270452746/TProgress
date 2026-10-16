import Foundation
import CoreData

// MARK: - Habit service
//
// Everything that belongs to the private practice side of the app: logging,
// goals, the counters a circle derives from its log, and the account's own
// streak. The counters used to be nudged by hand in three different views
// (`TodayView`, `CircleDetailView`, `ChatDetailView`), which is how they drifted
// apart. They are recomputed here instead, from the log itself.

enum HabitService {

    private static var context: NSManagedObjectContext { CoreDataStack.shared.context }

    // MARK: - Checking in

    @discardableResult
    static func logCheckIn(
        _ habit: CDHabit,
        amount: Double,
        unit: String,
        minutes: Int,
        note: String,
        isFreeze: Bool = false,
        date: Date = Date(),
        kind: CheckInKind = .standard,
        prompt: String? = nil
    ) -> CDCheckIn? {
        let entry = CDCheckIn(context: context)
        entry.id = UUID()
        entry.habit = habit
        entry.date = date
        entry.isMine = true
        // The setter keeps `isFreeze` in step, so anything still reading the old
        // flag sees the truth.
        entry.kind = isFreeze ? .freeze : kind
        // When the row was written, which for a backfilled day is not the same
        // as the day it describes. Only real write paths set this.
        entry.createdAt = Date()
        entry.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.amountValue = max(amount, 0)
        entry.amountUnit = unit.isEmpty ? "session" : unit
        entry.durationMinutes = Int32(max(minutes, 0))
        // A question with no words under it is not an answer, so a prompt is
        // only kept when something was actually written.
        entry.promptText = entry.hasNote ? prompt : nil

        // Doing the thing on a day that was declared a rest settles the day the
        // ordinary way; the rest was only ever a placeholder for it.
        clearRest(on: entry.day, for: habit)

        settle(habit)

        // Adding a day to the log is the only thing that can lengthen a run, so
        // this is the single place the ladder and the weekly payout are checked.
        // A day written up afterwards lengthens nothing, so it is not counted
        // here — otherwise the ladder could be climbed from hindsight.
        if entry.keepsTheRun {
            MilestonePresenter.shared.consider()
        }
        return entry
    }

    /// The one-tap path: a single session, no detail. Keeps the tap cheap and
    /// leaves the sheet for when there is something to say.
    @discardableResult
    static func quickLog(_ habit: CDHabit) -> CDCheckIn? {
        logCheckIn(habit, amount: 1, unit: "session", minutes: 0, note: "")
    }

    /// Today's log entry, when the practice is on it. A day declared as rest is
    /// not a log — it is the absence of one, marked in advance.
    static func todayCheckIn(for habit: CDHabit) -> CDCheckIn? {
        let calendar = Calendar.current
        return habit.checkIns.first {
            $0.isMine && !$0.isRest && calendar.isDateInToday($0.date ?? .distantPast)
        }
    }

    /// Rewrites the detail on an entry that already exists, which is what the
    /// sheet does when today has been logged and then described.
    static func update(
        _ checkIn: CDCheckIn,
        amount: Double,
        unit: String,
        minutes: Int,
        note: String,
        prompt: String? = nil
    ) {
        checkIn.amountValue = max(amount, 0)
        checkIn.amountUnit = unit.isEmpty ? "session" : unit
        checkIn.durationMinutes = Int32(max(minutes, 0))
        checkIn.note = note.trimmingCharacters(in: .whitespacesAndNewlines)

        // Describing a row makes it hand-written, which is what lets the hour it
        // was written at be read from it.
        if checkIn.createdAt == nil { checkIn.createdAt = Date() }

        if !checkIn.hasNote {
            checkIn.promptText = nil
        } else if let prompt {
            checkIn.promptText = prompt
        }

        if let habit = checkIn.habit {
            settle(habit)
        } else {
            saveAndRefreshUser()
        }
    }

    static func isCheckedToday(_ habit: CDHabit) -> Bool {
        todayCheckIn(for: habit) != nil
    }

    /// Undoes today's log for a circle, however many entries it holds.
    static func removeToday(_ habit: CDHabit) {
        let calendar = Calendar.current
        let today = habit.checkIns.filter {
            $0.isMine && calendar.isDateInToday($0.date ?? .distantPast)
        }
        for entry in today { context.delete(entry) }
        settle(habit)
    }

    static func remove(_ checkIn: CDCheckIn) {
        let habit = checkIn.habit
        context.delete(checkIn)
        if let habit {
            settle(habit)
        } else {
            saveAndRefreshUser()
        }
    }

    // MARK: - Counters
    //
    // `todayChecked`, `streak`, `totalMinutes` and `progress` are stored fields
    // the views already read, so they are written from the log rather than
    // replaced by computed properties. That keeps every existing call site
    // working and makes the numbers mean something.

    static func recomputeState(for habit: CDHabit) {
        let calendar = Calendar.current
        let mine = habit.checkIns.filter(\.isMine)

        // A rest settles the day without claiming the practice happened, so it
        // is never read as a check-in where the question is "did you do it".
        habit.todayChecked = mine.contains {
            !$0.isRest && calendar.isDateInToday($0.date ?? .distantPast)
        }
        habit.streak = Int32(habit.computedStreak)
        habit.totalMinutes = Int32(mine.reduce(0) { $0 + Int($1.durationMinutes) })
        habit.progress = habit.goalProgress
    }

    /// The account's run of days with at least one check-in in any joined
    /// circle. Only the signed-in user is recomputed: the seeded community
    /// carries streak numbers of its own that no log backs, and overwriting
    /// them with zero would flatten the whole feed.
    static func recomputeUserStreak(_ user: CDUser?) {
        guard let user, user.isCurrentUser else { return }

        let calendar = Calendar.current
        let joined = CoreDataStack.shared.fetch(
            CDHabit.self,
            predicate: NSPredicate(format: "isJoined == YES")
        )
        let mine = joined.flatMap(\.checkIns).filter(\.isMine)

        // The same streak-qualifying set the circle streak reads: every kind
        // except a day written up afterwards.
        let days = loggedDays(joinedOnly: true)

        // A rest is not a session and neither is a bought-back day, so the tally
        // the profile shows counts the days the practice actually happened.
        user.totalCheckIns = Int32(mine.filter(\.countsAsSession).count)
        guard !days.isEmpty else {
            user.streak = 0
            return
        }

        // Today not being logged yet does not break the run, so the count falls
        // back to yesterday until the day is opened.
        let today = calendar.startOfDay(for: Date())
        var cursor = days.contains(today)
            ? today
            : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)

        var run = 0
        while days.contains(cursor) {
            run += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        user.streak = Int32(run)
        user.longestStreak = max(user.longestStreak, Int32(longestRun(in: days)))
        user.lastCheckInDay = today
    }

    /// The longest unbroken run of days in a set of logged days.
    static func longestRun(in days: Set<Date>) -> Int {
        let calendar = Calendar.current
        let sorted = days.sorted()
        guard var previous = sorted.first else { return 0 }

        var best = 1
        var run = 1
        for day in sorted.dropFirst() {
            let gap = calendar.dateComponents([.day], from: previous, to: day).day ?? 0
            if gap == 1 {
                run += 1
            } else if gap > 1 {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }

    // MARK: - Goals

    static func setGoal(
        _ habit: CDHabit,
        type: GoalType,
        count: Int,
        weekdays: [HabitWeekday],
        amount: Double,
        unit: String
    ) {
        habit.goalType = type
        habit.goalCount = Int32(max(count, 0))
        habit.goalWeekdays = Int32(HabitWeekday.mask(weekdays))
        habit.goalAmount = max(amount, 0)
        habit.goalUnit = unit.trimmingCharacters(in: .whitespaces).isEmpty ? nil : unit

        // The free-text cadence stays in step with the structured goal, because
        // it is still what the card and the recap read out.
        habit.cadence = cadenceLabel(for: habit)

        settle(habit)
    }

    /// Restates a structured goal as the sentence the seed data used.
    private static func cadenceLabel(for habit: CDHabit) -> String {
        switch habit.goalType {
        case .daily:
            return "Daily"
        case .weeklyCount:
            return "\(max(habit.goalTarget, 1))× a week"
        case .weekdays:
            let days = habit.goalDays
            if days == HabitWeekday.days(in: HabitWeekday.weekdaysMask) { return "Weekdays" }
            return habit.goalLabel
        }
    }

    // MARK: - Minimum
    //
    // The smallest version of the practice that still counts. Not a shortcut
    // around the work — a floor under it, for the days when the full thing was
    // never going to happen and doing nothing was the alternative.

    static func setMinimum(_ habit: CDHabit, label: String, amount: Double, unit: String) {
        habit.minimumLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.minimumAmount = max(amount, 0)
        habit.minimumUnit = unit.trimmingCharacters(in: .whitespaces)
        CoreDataStack.shared.save()
    }

    static func clearMinimum(_ habit: CDHabit) {
        habit.minimumLabel = ""
        habit.minimumAmount = 0
        habit.minimumUnit = ""
        CoreDataStack.shared.save()
    }

    /// Logs the smallest version in one tap. It keeps the run alive exactly as a
    /// full session would — that is the whole point of having defined it.
    @discardableResult
    static func logMinimum(_ habit: CDHabit) -> CDCheckIn? {
        logCheckIn(
            habit,
            amount: max(habit.minimumAmount, 1),
            unit: habit.minimumResolvedUnit,
            minutes: 0,
            note: "",
            kind: .minimum
        )
    }

    // MARK: - Planned rest
    //
    // A day off decided in advance. It keeps the run alive and costs nothing, so
    // it can only be claimed ahead of time: a rest declared afterwards is not a
    // plan, it is a story, and the value of this log is that it does not contain
    // those.
    //
    // That is also what separates it from a freeze card. The card buys a day
    // back after the fact and is scarce; this is free, and has to be honest
    // instead.

    /// How far ahead a rest can be declared. Today or tomorrow is a plan; a week
    /// out is an excuse.
    static let restLookaheadDays = 1

    /// Whether the practice is on the log for a given day.
    static func isChecked(_ habit: CDHabit, on day: Date) -> Bool {
        let calendar = Calendar.current
        let target = calendar.startOfDay(for: day)
        return habit.checkIns.contains {
            $0.isMine && !$0.isRest
                && calendar.startOfDay(for: $0.date ?? .distantPast) == target
        }
    }

    /// The rest entry declared for a day, if there is one.
    static func restDay(for habit: CDHabit, on day: Date) -> CDCheckIn? {
        let calendar = Calendar.current
        let target = calendar.startOfDay(for: day)
        return habit.checkIns.first {
            $0.isMine && $0.isRest
                && calendar.startOfDay(for: $0.date ?? .distantPast) == target
        }
    }

    static func hasRested(_ habit: CDHabit, on day: Date) -> Bool {
        restDay(for: habit, on: day) != nil
    }

    /// Declares a rest. Today or tomorrow only, and never a day the practice is
    /// already on.
    @discardableResult
    static func declareRest(_ habit: CDHabit, on day: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: day)

        guard habit.isJoined else { return false }
        guard target >= today else { return false }
        guard let horizon = calendar.date(byAdding: .day, value: restLookaheadDays, to: today),
              target <= horizon
        else { return false }
        guard !isChecked(habit, on: target) else { return false }
        guard restDay(for: habit, on: target) == nil else { return false }

        let entry = CDCheckIn(context: context)
        entry.id = UUID()
        entry.habit = habit
        entry.date = target
        entry.isMine = true
        entry.kind = .rest
        entry.createdAt = Date()
        entry.note = ""
        entry.amountValue = 0
        entry.amountUnit = "rested"
        entry.durationMinutes = 0

        settle(habit)
        // A rest lengthens the run, so declaring one can cross a rung.
        MilestonePresenter.shared.consider()
        return true
    }

    static func cancelRest(_ habit: CDHabit, on day: Date = Date()) {
        guard let entry = restDay(for: habit, on: day) else { return }
        context.delete(entry)
        settle(habit)
    }

    /// Drops the rest placeholder on a day the practice ended up happening.
    private static func clearRest(on day: Date, for habit: CDHabit) {
        guard let entry = restDay(for: habit, on: day) else { return }
        context.delete(entry)
    }

    // MARK: - Backfill
    //
    // Writing up a day that has already gone. The window is deliberately short —
    // a week of hindsight is a spreadsheet, three days is a memory — and a
    // backfilled day never lengthens a run. It makes the record complete; it
    // does not rewrite it.

    /// How many days back a day can still be written up.
    static let backfillWindow = 3

    /// Whether a day is still inside the window: recent, in the past, not today.
    static func canBackfill(_ day: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: day)
        guard let earliest = calendar.date(byAdding: .day, value: -backfillWindow, to: today)
        else { return false }
        return target >= earliest && target < today
    }

    /// The days still open, most recent first. Today is not among them — today
    /// has its own door.
    static func backfillableDays(for habit: CDHabit) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (1...backfillWindow).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today)
            else { return nil }
            return isChecked(habit, on: day) ? nil : day
        }
    }

    @discardableResult
    static func logBackfill(
        _ habit: CDHabit,
        on day: Date,
        amount: Double,
        unit: String,
        minutes: Int,
        note: String
    ) -> CDCheckIn? {
        guard habit.isJoined, canBackfill(day), !isChecked(habit, on: day) else { return nil }

        let calendar = Calendar.current
        return logCheckIn(
            habit,
            amount: amount,
            unit: unit,
            minutes: minutes,
            note: note,
            date: calendar.startOfDay(for: day),
            kind: .backfill
        )
    }

    // MARK: - Freeze cards
    //
    // Earned, never bought. Two things pay out: a rung on the milestone ladder,
    // and a week kept whole. `lastMilestoneAwarded` and
    // `lastPerfectWeekAwardedAt` are the high-water marks that stop a payout
    // being made twice.

    static let freezeCardCap = 3

    /// Past the cap a card is simply not granted, so a long unbroken run does
    /// not turn into a stockpile.
    @discardableResult
    private static func grantFreezeCards(_ count: Int, to user: CDUser) -> Int {
        guard count > 0 else { return 0 }
        let room = max(freezeCardCap - Int(user.freezeTokens), 0)
        let granted = min(count, room)
        user.freezeTokens += Int32(granted)
        return granted
    }

    /// Credits every rung the streak has reached since it was last checked —
    /// which matters when a single log jumps two rungs at once. Returns the
    /// rung to celebrate and how many cards it paid out.
    static func evaluateMilestones() -> (reached: Int, cards: Int)? {
        guard let user = AppSession.shared.currentUser else { return nil }

        let streak = Int(user.streak)
        let reached = Milestone.reached(upTo: streak) ?? 0
        let previous = Int(user.lastMilestoneAwarded)

        guard reached > previous else { return nil }

        let crossed = Milestone.crossed(from: previous, to: streak)
        let granted = grantFreezeCards(crossed.count, to: user)
        user.lastMilestoneAwarded = Int32(reached)
        CoreDataStack.shared.save()

        return (reached, granted)
    }

    /// A calendar week with every one of its days logged, in any joined circle.
    @discardableResult
    static func grantPerfectWeekIfEarned() -> Int {
        guard let user = AppSession.shared.currentUser else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: today),
              let week = calendar.dateInterval(of: .weekOfYear, for: lastWeek) else { return 0 }

        // Already paid out for this week.
        if let awarded = user.lastPerfectWeekAwardedAt, week.contains(awarded) { return 0 }

        let logged = loggedDays(joinedOnly: true)
        let covered = (0..<7).allSatisfy { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: week.start) else { return false }
            return logged.contains(calendar.startOfDay(for: day))
        }
        guard covered else { return 0 }

        let granted = grantFreezeCards(1, to: user)
        user.lastPerfectWeekAwardedAt = week.start
        CoreDataStack.shared.save()
        return granted
    }

    /// The most recent day that would have kept a run going but was missed —
    /// the day a freeze card is allowed to buy back.
    static func missedYesterday(_ habit: CDHabit) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return false }
        let logged = Set(
            habit.checkIns
                .filter(\.isMine)
                .map { calendar.startOfDay(for: $0.date ?? .distantPast) }
        )
        return !logged.contains(yesterday) && !logged.isEmpty
    }

    /// Spends a card to put yesterday back on the log. The entry is marked
    /// `isFreeze`, so the day counts toward the streak without pretending the
    /// session happened.
    @discardableResult
    static func restoreYesterday(_ habit: CDHabit) -> Bool {
        guard let user = AppSession.shared.currentUser, user.freezeTokens > 0 else { return false }
        guard missedYesterday(habit) else { return false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return false }

        let entry = CDCheckIn(context: context)
        entry.id = UUID()
        entry.habit = habit
        entry.date = yesterday
        entry.isMine = true
        entry.kind = .freeze
        entry.createdAt = Date()
        entry.note = "Bought back with a freeze card"
        entry.amountValue = 0
        entry.amountUnit = "restored"
        entry.durationMinutes = 0

        user.freezeTokens -= 1
        settle(habit)

        // The restored day lengthens the run, so the ladder is re-read here too.
        MilestonePresenter.shared.consider()
        return true
    }

    // MARK: - Reading the log

    /// Every day with at least one entry that keeps a run alive, as start-of-day
    /// values.
    ///
    /// Days written up afterwards are left out. They are real, and they count as
    /// presence everywhere else — but they do not repair a break, and a week
    /// completed out of them would pay out a freeze card for work that did not
    /// happen on the day. That is the only reward this app hands out, and it is
    /// meant to be earned by returning rather than by remembering.
    static func loggedDays(joinedOnly: Bool) -> Set<Date> {
        let calendar = Calendar.current
        let habits = CoreDataStack.shared.fetch(
            CDHabit.self,
            predicate: joinedOnly ? NSPredicate(format: "isJoined == YES") : nil
        )
        return Set(
            habits
                .flatMap(\.checkIns)
                .filter { $0.isMine && $0.keepsTheRun }
                .compactMap { $0.date.map { calendar.startOfDay(for: $0) } }
        )
    }

    // MARK: - Committing

    /// Recomputes the circle, the account, and saves — the tail every mutation
    /// above shares.
    private static func settle(_ habit: CDHabit) {
        recomputeState(for: habit)
        recomputeUserStreak(AppSession.shared.currentUser)
        CoreDataStack.shared.save()
    }

    private static func saveAndRefreshUser() {
        recomputeUserStreak(AppSession.shared.currentUser)
        CoreDataStack.shared.save()
    }
}
