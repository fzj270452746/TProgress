import Foundation
import CoreData

// MARK: - Recap service
//
// Stage recaps used to be three rows the seed wrote with fixed numbers and a
// trend drawn from a random generator. They are computed here instead: one
// summary per circle per period, refreshed rather than accumulated, so a circle
// always has exactly three recaps and they always describe the last 30 days,
// six weeks and quarter rather than whenever they happened to be created.

enum RecapService {

    private static var context: NSManagedObjectContext { CoreDataStack.shared.context }

    // MARK: - Reading

    static func all(for habit: CDHabit) -> [CDStageSummary] {
        habit.summaries.sorted {
            ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
        }
    }

    /// Only the generated ones. The three the seed wrote carry no `kindRaw`
    /// and are left where they are.
    static func generated(for habit: CDHabit) -> [CDStageSummary] {
        RecapKind.allCases.compactMap { summary(for: habit, kind: $0) }
    }

    static func summary(for habit: CDHabit, kind: RecapKind) -> CDStageSummary? {
        habit.summaries.first { $0.kind == kind }
    }

    /// How many sessions the account actually put in over the recap's period. A
    /// rest is not one, and neither is a bought-back day.
    static func sessions(of summary: CDStageSummary) -> Int {
        guard let habit = summary.habit else { return 0 }
        return workEntries(of: habit, in: period(of: summary)).count
    }

    private static func period(of summary: CDStageSummary) -> DateInterval? {
        guard let start = summary.periodStart, let end = summary.periodEnd, end > start else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// Days in the period that carry at least one of the account's check-ins.
    static func loggedDays(of summary: CDStageSummary) -> Int {
        guard let habit = summary.habit else { return 0 }
        let calendar = Calendar.current
        return Set(
            entries(of: habit, in: period(of: summary))
                .compactMap { $0.date.map { calendar.startOfDay(for: $0) } }
        ).count
    }

    /// How many days the period spans.
    static func periodDays(of summary: CDStageSummary) -> Int {
        guard let interval = period(of: summary) else { return 0 }
        return max((Calendar.current.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0) + 1, 1)
    }

    /// The period cut into six, each bucket holding what was actually logged in
    /// it — the real shape behind the volume chart, rather than a trend curve
    /// scaled by a total.
    static func volumeBuckets(of summary: CDStageSummary) -> [Double] {
        let buckets = 6
        guard let habit = summary.habit, let interval = period(of: summary) else {
            return Array(repeating: 0, count: buckets)
        }

        let span = interval.duration / Double(buckets)
        guard span > 0 else { return Array(repeating: 0, count: buckets) }

        var values = Array(repeating: 0.0, count: buckets)
        // Effort, not presence: a rest day contributes nothing to the shape.
        for entry in workEntries(of: habit, in: interval) {
            guard let date = entry.date else { continue }
            let offset = date.timeIntervalSince(interval.start) / span
            let index = min(max(Int(offset), 0), buckets - 1)
            values[index] += entry.amountValue
        }
        return values
    }

    private static func entries(of habit: CDHabit, in interval: DateInterval?) -> [CDCheckIn] {
        // `filter` on a Set hands back a Set, so the array is rebuilt explicitly.
        let mine = Array(habit.checkIns.filter(\.isMine))
        guard let interval else { return mine }
        return mine.filter { entry in
            guard let date = entry.date else { return false }
            return date >= interval.start && date <= interval.end
        }
    }

    /// The entries where the work actually happened. A rest and a bought-back day
    /// are presence without effort, so everything measuring effort reads this
    /// instead — including the unit, which would otherwise be resolved as
    /// "rested" for a circle with a lot of them.
    private static func workEntries(of habit: CDHabit, in interval: DateInterval?) -> [CDCheckIn] {
        entries(of: habit, in: interval).filter(\.countsAsSession)
    }

    /// Days in the period the account set aside as rest.
    private static func restDays(of habit: CDHabit, in interval: DateInterval?) -> Int {
        let calendar = Calendar.current
        return Set(
            entries(of: habit, in: interval)
                .filter(\.isRest)
                .compactMap { $0.date.map { calendar.startOfDay(for: $0) } }
        ).count
    }

    // MARK: - Generating

    static func syncAllJoined() {
        let joined = CoreDataStack.shared.fetch(
            CDHabit.self,
            predicate: NSPredicate(format: "isJoined == YES")
        )
        guard !joined.isEmpty else { return }

        for habit in joined {
            syncRecaps(for: habit)
        }
        CoreDataStack.shared.save()
    }

    /// Creates or refreshes one recap per period for a circle.
    static func syncRecaps(for habit: CDHabit) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for kind in RecapKind.allCases {
            guard let start = calendar.date(byAdding: .day, value: -(kind.days - 1), to: today) else { continue }
            let interval = DateInterval(start: start, end: today)

            let summary = summary(for: habit, kind: kind) ?? makeSummary(for: habit, kind: kind)
            apply(habit: habit, kind: kind, interval: interval, to: summary)
        }
    }

    private static func makeSummary(for habit: CDHabit, kind: RecapKind) -> CDStageSummary {
        let summary = CDStageSummary(context: context)
        summary.id = UUID()
        summary.habit = habit
        summary.kind = kind
        summary.createdAt = Date()
        summary.seed = habit.seed &+ Int64(kind.days)
        return summary
    }

    private static func apply(
        habit: CDHabit,
        kind: RecapKind,
        interval: DateInterval,
        to summary: CDStageSummary
    ) {
        let calendar = Calendar.current
        let entries = entries(of: habit, in: interval)
        let work = workEntries(of: habit, in: interval)
        let rests = restDays(of: habit, in: interval)

        // Presence, which includes a rest: the day did not go by unaccounted for.
        let loggedDays = Set(entries.compactMap { $0.date.map { calendar.startOfDay(for: $0) } })
        // Doing, which does not.
        let workedDays = Set(work.compactMap { $0.date.map { calendar.startOfDay(for: $0) } })

        summary.title = "\(habit.title) · \(kind.label)"
        summary.periodStart = interval.start
        summary.periodEnd = interval.end
        // Read off the work, so a circle with a lot of rests does not end up
        // reporting its totals in "rested".
        summary.unit = unit(for: habit, entries: work)
        summary.totalValue = work.reduce(0) { $0 + $1.amountValue }
        summary.completionRate = completionRate(
            habit: habit,
            interval: interval,
            workedDays: workedDays,
            restDays: rests
        )
        summary.reflection = reflection(
            habit: habit,
            kind: kind,
            loggedDays: loggedDays.count,
            sessions: work.count,
            rests: rests
        )
    }

    /// Consistency against what the goal actually asked for, not against every
    /// day on the calendar.
    ///
    /// Rest days come off the ask rather than counting as an answer, so taking
    /// one neither helps nor hurts. It removes the question instead of answering
    /// it, which is the only way this number stays worth reading.
    private static func completionRate(
        habit: CDHabit,
        interval: DateInterval,
        workedDays: Set<Date>,
        restDays: Int
    ) -> Double {
        let calendar = Calendar.current
        let span = max((calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0) + 1, 1)

        let asked: Int
        switch habit.goalType {
        case .daily:
            asked = span
        case .weeklyCount:
            asked = max(Int((Double(max(habit.goalTarget, 1)) * Double(span) / 7).rounded()), 1)
        case .weekdays:
            let mask = habit.goalWeekdayMask
            asked = mask == 0 ? span : (0..<span).reduce(0) { total, offset in
                guard let day = calendar.date(byAdding: .day, value: offset, to: interval.start) else { return total }
                let weekday = calendar.component(.weekday, from: day)
                return total + (HabitWeekday.contains(mask, HabitWeekday(rawValue: weekday) ?? .sunday) ? 1 : 0)
            }
        }

        let expected = max(asked - restDays, 0)
        guard expected > 0 else { return workedDays.isEmpty ? 0 : 1 }
        return min(1, Double(workedDays.count) / Double(expected))
    }

    /// Prefers the circle's own goal unit, falling back to whatever the entries
    /// were actually recorded in.
    private static func unit(for habit: CDHabit, entries: [CDCheckIn]) -> String? {
        if let declared = habit.goalUnit, !declared.isEmpty { return declared }

        let counts = entries.reduce(into: [String: Int]()) { result, entry in
            guard let unit = entry.amountUnit, !unit.isEmpty else { return }
            result[unit, default: 0] += 1
        }
        return counts.max { $0.value < $1.value }?.key
    }

    /// Written from the numbers rather than picked from a list, so it stays true
    /// when the log changes.
    private static func reflection(
        habit: CDHabit,
        kind: RecapKind,
        loggedDays: Int,
        sessions: Int,
        rests: Int
    ) -> String {
        let span = kind.days
        guard sessions > 0 else {
            return "Nothing logged in this window. The recap is here when you want to start again."
        }

        let missed = max(span - loggedDays, 0)
        let shape: String
        switch Double(loggedDays) / Double(span) {
        case 0.85...:  shape = "Almost unbroken."
        case 0.6..<0.85: shape = "Steady, with the gaps you would expect."
        case 0.3..<0.6: shape = "Uneven, and still moving."
        default:        shape = "Thin, but not nothing."
        }

        var tail = missed == 0
            ? "Not a day missed."
            : "\(missed) day\(missed == 1 ? "" : "s") went by without it, and the log came back either way."

        // Named rather than folded into the gaps, because a rest is not one.
        if rests > 0 {
            tail += " \(rests) more \(rests == 1 ? "was" : "were") set aside in advance."
        }

        return "\(loggedDays) of \(span) days on \(habit.title) — \(sessions) session\(sessions == 1 ? "" : "s"). \(shape) \(tail)"
    }

    // MARK: - Publishing

    /// Turns a recap into a post, tagged to the circle it came from. Returns nil
    /// when there is nothing worth saying or the account is not signed in.
    @discardableResult
    static func publish(_ summary: CDStageSummary) -> CDPost? {
        guard let habit = summary.habit else { return nil }
        guard summary.completionRate > 0 || summary.totalValue > 0 else { return nil }

        let percent = Int((summary.completionRate * 100).rounded())
        let body = """
        \(summary.heading) — \(percent)% of what the goal asked for, \(summary.totalLabel).
        \(summary.reflectionText)
        """

        return CommunityService.createPost(
            text: body,
            kind: .summary,
            topic: habit.category?.lowercased(),
            habitName: habit.title,
            amount: summary.totalValue,
            unit: summary.unit ?? "",
            minutes: 0,
            media: [],
            taggedHabitID: habit.id
        )
    }
}
