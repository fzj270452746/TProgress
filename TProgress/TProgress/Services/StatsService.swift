import Foundation
import CoreData

// MARK: - Stats service
//
// Read-only aggregation over the account's own log.
//
// The dashboard wants ten numbers at once, and each one walks the same log. So
// the work is done as a single pass: `totals()` fetches the circles once and
// buckets every check-in by day, and `snapshot()` derives the whole page from
// that one dictionary. Nothing here queries per cell, per day or per circle.
//
// Scope is always the circles actually joined. The seed writes check-ins for
// every circle including unjoined ones, so counting by `isMine` alone would
// report practice in circles the person never entered.

enum StatsService {

    // MARK: - One pass over the log

    struct DayTotal {
        /// Entries where the practice actually happened.
        var circles: Int = 0
        var minutes: Int = 0
        var amount: Double = 0

        /// Days answered without the practice happening: a declared rest, a day
        /// bought back with a freeze card, a day written up afterwards.
        var rests: Int = 0
        var boughtBack: Int = 0
        var backfilled: Int = 0

        /// Whether any entry that day keeps a run alive. A day holding both a
        /// backfilled entry and a real one is a real day.
        var keepsRun: Bool = false
    }

    struct CircleTotal {
        var title: String
        var count: Int
        var accentIndex: Int
    }

    /// The circles actually joined. Internal rather than private because every
    /// surface that reports on the log needs the same scope, and re-deriving it
    /// in each one is how the numbers drift apart.
    static func joinedCircles() -> [CDHabit] {
        CoreDataStack.shared.fetch(
            CDHabit.self,
            predicate: NSPredicate(format: "isJoined == YES"),
            sortBy: [TPSort.byName]
        )
    }

    private static func totals(_ circles: [CDHabit]) -> [Date: DayTotal] {
        let calendar = Calendar.current
        var result: [Date: DayTotal] = [:]

        for habit in circles {
            for entry in habit.checkIns where entry.isMine {
                guard let date = entry.date else { continue }
                let day = calendar.startOfDay(for: date)
                var total = result[day] ?? DayTotal()

                // The day is marked whatever the entry was, so a rest still
                // registers as a day that was answered. What the entry *was*
                // decides whether it also adds to the effort: a rest and a
                // bought-back day are days nothing happened on.
                if entry.countsAsSession {
                    total.circles += 1
                    total.minutes += Int(entry.durationMinutes)
                    total.amount += entry.amountValue
                }

                switch entry.kind {
                case .rest:     total.rests += 1
                case .freeze:   total.boughtBack += 1
                case .backfill: total.backfilled += 1
                case .standard, .minimum: break
                }

                if entry.keepsTheRun { total.keepsRun = true }

                result[day] = total
            }
        }
        return result
    }

    // MARK: - Snapshot

    /// Everything the dashboard and the year review need, derived from one read.
    struct Snapshot {
        var activeDays = 0
        var sessions = 0
        var minutes = 0
        var currentStreak = 0
        var longestStreak = 0

        /// Share of what the goals asked for over the last 30 days.
        var completionRate = 0.0

        /// One entry per week, oldest first, seven day values each.
        var heatmap: [[Double]] = []
        var heatmapWeeks = 0

        var monthValues: [Double] = []
        var monthLabels: [String] = []

        var share: [CircleTotal] = []
        var years: [Int] = []
    }

    static func snapshot(heatmapWeeks: Int = 26, months: Int = 6, shareLimit: Int = 5) -> Snapshot {
        let calendar = Calendar.current
        let circles = joinedCircles()
        let days = totals(circles)
        let today = calendar.startOfDay(for: Date())

        var snapshot = Snapshot()
        // The continuity set, which is not the same as the days present in the
        // log: a day written up afterwards is in the log but not in a run.
        let streakDays = Set(days.filter { $0.value.keepsRun }.keys)

        snapshot.activeDays = days.count
        snapshot.sessions = days.values.reduce(0) { $0 + $1.circles }
        snapshot.minutes = days.values.reduce(0) { $0 + $1.minutes }
        snapshot.currentStreak = currentStreak(in: streakDays, today: today, calendar: calendar)
        snapshot.longestStreak = HabitService.longestRun(in: streakDays)
        snapshot.completionRate = completionRate(circles: circles, days: days, span: 30)
        snapshot.heatmapWeeks = heatmapWeeks
        snapshot.heatmap = heatmap(days: days, weeks: heatmapWeeks, today: today, calendar: calendar)
        snapshot.monthValues = monthValues(days: days, months: months, today: today, calendar: calendar).values
        snapshot.monthLabels = monthValues(days: days, months: months, today: today, calendar: calendar).labels
        snapshot.share = share(circles: circles, limit: shareLimit)
        snapshot.years = years(days: days, today: today, calendar: calendar)
        return snapshot
    }

    // MARK: - Derivations

    /// Consecutive days that kept a run alive, ending today. Takes the continuity
    /// set rather than the whole log, so a day written up afterwards cannot
    /// extend anything.
    private static func currentStreak(in days: Set<Date>, today: Date, calendar: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }

        // Today not answered yet does not break the run.
        var cursor = days.contains(today)
            ? today
            : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)

        var run = 0
        while days.contains(cursor) {
            run += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return run
    }

    /// Days the work happened, against days the goals actually asked for — not
    /// against every day on the calendar, and not against days that were rested.
    ///
    /// A rest is subtracted from the ask rather than counted as an answer, so
    /// declaring one neither helps nor hurts: it removes the question instead of
    /// answering it. Nothing can be gained by resting, which is the only way
    /// this number stays worth reading.
    private static func completionRate(circles: [CDHabit], days: [Date: DayTotal], span: Int) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(span - 1), to: today) else { return 0 }

        let window = days.filter { $0.key >= start && $0.key <= today }
        // Days the practice happened on. A rest-only day has no sessions on it.
        let logged = window.values.reduce(0) { $0 + ($1.circles > 0 ? 1 : 0) }

        let asked = circles.reduce(0) { total, habit in
            total + expectedDays(for: habit, from: start, to: today, calendar: calendar)
        }
        let rested = circles.reduce(0) { total, habit in
            total + habit.restedDays.filter { $0 >= start && $0 <= today }.count
        }

        let expected = max(asked - rested, 0)
        guard expected > 0 else { return logged > 0 ? 1 : 0 }
        return min(1, Double(logged) / Double(expected))
    }

    private static func expectedDays(for habit: CDHabit, from start: Date, to end: Date, calendar: Calendar) -> Int {
        let span = max((calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1, 1)

        switch habit.goalType {
        case .daily:
            return span

        case .weeklyCount:
            let weeks = Double(span) / 7
            return max(Int((Double(max(habit.goalTarget, 1)) * weeks).rounded()), 1)

        case .weekdays:
            let mask = habit.goalWeekdayMask
            guard mask != 0 else { return span }
            return max((0..<span).reduce(0) { total, offset in
                guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return total }
                let weekday = calendar.component(.weekday, from: day)
                return total + (HabitWeekday.contains(mask, HabitWeekday(rawValue: weekday) ?? .sunday) ? 1 : 0)
            }, 1)
        }
    }

    private static func heatmap(
        days: [Date: DayTotal],
        weeks: Int,
        today: Date,
        calendar: Calendar
    ) -> [[Double]] {
        guard weeks > 0,
              let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }

        var columns: [[Double]] = []
        for column in stride(from: weeks - 1, through: 0, by: -1) {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -column, to: thisWeekStart) else {
                continue
            }

            var rows: [Double] = []
            for offset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                    rows.append(0)
                    continue
                }
                let key = calendar.startOfDay(for: day)
                guard key <= today else {
                    rows.append(-1)   // a day that has not happened yet
                    continue
                }

                let total = days[key]
                let sessions = total?.circles ?? 0
                let settledWithoutWork = (total?.rests ?? 0) + (total?.boughtBack ?? 0) > 0

                // A day that was answered without the work happening — rested on
                // purpose, or bought back — is drawn faintly rather than left as
                // a hole. It was not a missed day, and the grid should not say it
                // was.
                rows.append(
                    sessions > 0
                        ? intensity(forCircles: sessions)
                        : (settledWithoutWork ? 0.22 : 0)
                )
            }
            columns.append(rows)
        }
        return columns
    }

    private static func intensity(forCircles count: Int) -> Double {
        switch count {
        case 0:   return 0
        case 1:   return 0.34
        case 2:   return 0.62
        default:  return 1
        }
    }

    private static func monthValues(
        days: [Date: DayTotal],
        months: Int,
        today: Date,
        calendar: Calendar
    ) -> (values: [Double], labels: [String]) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        var values: [Double] = []
        var labels: [String] = []

        for step in stride(from: months - 1, through: 0, by: -1) {
            guard let anchor = calendar.date(byAdding: .month, value: -step, to: today),
                  let interval = calendar.dateInterval(of: .month, for: anchor) else { continue }

            let count = days
                .filter { $0.key >= interval.start && $0.key < interval.end }
                .values
                .reduce(0) { $0 + $1.circles }

            values.append(Double(count))
            labels.append(formatter.string(from: interval.start))
        }
        return (values, labels)
    }

    private static func share(circles: [CDHabit], limit: Int) -> [CircleTotal] {
        circles
            .compactMap { habit -> CircleTotal? in
                // Only the days something was done. A rest day is not time that
                // went anywhere, and a bought-back day is not either.
                let count = habit.checkIns.filter { $0.isMine && $0.countsAsSession }.count
                guard count > 0 else { return nil }
                return CircleTotal(title: habit.title, count: count, accentIndex: Int(habit.accentIndex))
            }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
    }

    private static func years(days: [Date: DayTotal], today: Date, calendar: Calendar) -> [Int] {
        var all = Set(days.keys.map { calendar.component(.year, from: $0) })
        all.insert(calendar.component(.year, from: today))
        return all.sorted(by: >)
    }

    // MARK: - Grid furniture

    /// Row labels in the calendar's own week order, so the grid agrees with the
    /// dates printed beside it.
    static func weekdayLabels() -> [String] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { index in
            let weekday = ((first - 1 + index) % 7) + 1
            return HabitWeekday(rawValue: weekday)?.initial ?? "?"
        }
    }

    /// Column index → month abbreviation, for the few columns that open a month.
    static func heatmapMonthLabels(weeks: Int) -> [Int: String] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [:] }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        var labels: [Int: String] = [:]
        var lastMonth = -1

        for column in 0..<weeks {
            guard let weekStart = calendar.date(
                byAdding: .weekOfYear,
                value: -(weeks - 1 - column),
                to: thisWeekStart
            ) else { continue }

            let month = calendar.component(.month, from: weekStart)
            if month != lastMonth {
                labels[column] = formatter.string(from: weekStart)
                lastMonth = month
            }
        }
        return labels
    }

    // MARK: - Year

    struct YearTotals {
        var sessions = 0
        var minutes = 0
        var activeDays = 0
        var longestStreak = 0
        var bestMonth: String?
        var topCircle: String?
        var firstDay: Date?
        var hasAnything: Bool { sessions > 0 }
    }

    static func yearTotals(_ year: Int) -> YearTotals {
        let calendar = Calendar.current
        let circles = joinedCircles()
        let days = totals(circles).filter { calendar.component(.year, from: $0.key) == year }

        var result = YearTotals()
        result.sessions = days.values.reduce(0) { $0 + $1.circles }
        result.minutes = days.values.reduce(0) { $0 + $1.minutes }
        result.activeDays = days.count
        // The continuity set again: a day written up afterwards is present in
        // the log but absent from any run.
        result.longestStreak = HabitService.longestRun(in: Set(days.filter { $0.value.keepsRun }.keys))
        result.firstDay = days.keys.min()

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"

        let byMonth = Dictionary(grouping: days.keys) { calendar.component(.month, from: $0) }
            .mapValues { keys in
                keys.reduce(0) { $0 + (days[$1]?.circles ?? 0) }
            }

        if let busiest = byMonth.max(by: { $0.value < $1.value })?.key,
           let anchor = calendar.date(from: DateComponents(year: year, month: busiest, day: 1)) {
            result.bestMonth = formatter.string(from: anchor)
        }

        result.topCircle = circles
            .compactMap { habit -> (String, Int)? in
                let count = habit.checkIns
                    .filter { $0.isMine && $0.countsAsSession }
                    .filter { entry in
                        guard let date = entry.date else { return false }
                        return calendar.component(.year, from: date) == year
                    }
                    .count
                return count > 0 ? (habit.title, count) : nil
            }
            .max { $0.1 < $1.1 }?
            .0

        return result
    }
}
