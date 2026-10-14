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
        isFreeze: Bool = false
    ) -> CDCheckIn? {
        let entry = CDCheckIn(context: context)
        entry.id = UUID()
        entry.habit = habit
        entry.date = Date()
        entry.isMine = true
        entry.isFreeze = isFreeze
        entry.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.amountValue = max(amount, 0)
        entry.amountUnit = unit.isEmpty ? "session" : unit
        entry.durationMinutes = Int32(max(minutes, 0))

        settle(habit)

        // Adding a day to the log is the only thing that can lengthen a run, so
        // this is the single place the ladder and the weekly payout are checked.
        MilestonePresenter.shared.consider()
        return entry
    }

    /// The one-tap path: a single session, no detail. Keeps the tap cheap and
    /// leaves the sheet for when there is something to say.
    @discardableResult
    static func quickLog(_ habit: CDHabit) -> CDCheckIn? {
        logCheckIn(habit, amount: 1, unit: "session", minutes: 0, note: "")
    }

    static func todayCheckIn(for habit: CDHabit) -> CDCheckIn? {
        let calendar = Calendar.current
        return habit.checkIns.first {
            $0.isMine && calendar.isDateInToday($0.date ?? .distantPast)
        }
    }

    /// Rewrites the detail on an entry that already exists, which is what the
    /// sheet does when today has been logged and then described.
    static func update(
        _ checkIn: CDCheckIn,
        amount: Double,
        unit: String,
        minutes: Int,
        note: String
    ) {
        checkIn.amountValue = max(amount, 0)
        checkIn.amountUnit = unit.isEmpty ? "session" : unit
        checkIn.durationMinutes = Int32(max(minutes, 0))
        checkIn.note = note.trimmingCharacters(in: .whitespacesAndNewlines)

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

        habit.todayChecked = mine.contains { calendar.isDateInToday($0.date ?? .distantPast) }
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
        let days = Set(mine.compactMap { $0.date.map { calendar.startOfDay(for: $0) } })

        user.totalCheckIns = Int32(mine.count)
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
        entry.isFreeze = true
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

    /// Every day with at least one check-in, as start-of-day values.
    static func loggedDays(joinedOnly: Bool) -> Set<Date> {
        let calendar = Calendar.current
        let habits = CoreDataStack.shared.fetch(
            CDHabit.self,
            predicate: joinedOnly ? NSPredicate(format: "isJoined == YES") : nil
        )
        return Set(
            habits
                .flatMap(\.checkIns)
                .filter(\.isMine)
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
