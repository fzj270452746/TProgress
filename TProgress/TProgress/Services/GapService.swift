import Foundation

// MARK: - Gap service
//
// The only thing in this app that measures coming back rather than not stopping.
//
// A streak counts the days you did not miss. It says nothing about the days you
// did miss, and nothing at all about what happened next — whether you came back
// the following morning, or a week later, or not until the month after. That
// return is the practice this app is actually about, so it gets its own numbers
// and its own page.
//
// Nothing here scolds. A gap is a fact about the record, and the figure worth
// putting at the top of the page is how long it usually takes to come back.

enum GapService {

    struct Gap: Identifiable {
        let id: Int
        /// First day missed.
        let missedFrom: Date
        /// Last day missed.
        let missedTo: Date
        /// The day the log came back, when it has.
        let returnedOn: Date?
        /// How many days went by.
        let length: Int

        var isOpen: Bool { returnedOn == nil }
    }

    struct Report {
        /// Most recent first, with any absence still running at the head.
        var gaps: [Gap] = []

        /// Mean days away before coming back, over the absences that ended.
        /// Nil when none has ended yet — an absence still running has no return
        /// to measure, and averaging it in would invent one.
        var averageReturn: Double?

        var longestAbsence: Int = 0
        var returns: Int = 0

        /// Days away right now. Zero whenever today has been answered.
        var awayNow: Int = 0

        /// One entry per day from the first day on record, oldest first.
        var presence: [Bool] = []
        /// Week-aligned, for `TPHeatmap`. 1 present, 0 absent, -1 not part of
        /// the record.
        var columns: [[Double]] = []

        var observedDays: Int = 0
        var firstDay: Date?

        var hasAnything: Bool { observedDays > 0 }
        var hasGaps: Bool { !gaps.isEmpty }
        /// A gap needs a day before it and a day after it to be a gap at all.
        var canRead: Bool { observedDays >= 4 }
    }

    static func report(span: Int = 182) -> Report {
        report(for: StatsService.joinedCircles(), span: span)
    }

    static func report(for circles: [CDHabit], span: Int = 182) -> Report {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Days the run was kept alive. Rest days are in — keeping a run going is
        // exactly what they are for — and days written up afterwards are out.
        var kept: Set<Date> = []
        for habit in circles {
            kept.formUnion(habit.streakDays)
        }

        guard let firstDay = kept.min() else { return Report() }

        // The scan opens on the first day on record, not on the edge of the
        // window. An account three days old should not open onto a 179-day gap,
        // which would be both wrong and dispiriting.
        let windowStart = calendar.date(byAdding: .day, value: -(span - 1), to: today) ?? firstDay
        let start = max(firstDay, windowStart)

        var report = Report()
        report.firstDay = firstDay

        var days: [Date] = []
        var cursor = start
        while cursor <= today {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        report.observedDays = days.count
        report.presence = days.map { kept.contains($0) }

        // Today is in progress, not missed, so it never closes a gap. A run that
        // is currently broken is reported through `awayNow` instead.
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        var gaps: [Gap] = []
        var missedFrom: Date?
        for day in days {
            if kept.contains(day) {
                if let began = missedFrom {
                    let last = calendar.date(byAdding: .day, value: -1, to: day) ?? began
                    let length = (calendar.dateComponents([.day], from: began, to: day).day ?? 1)
                    gaps.append(Gap(
                        id: gaps.count,
                        missedFrom: began,
                        missedTo: last,
                        returnedOn: day,
                        length: max(length, 1)
                    ))
                    missedFrom = nil
                }
            } else if missedFrom == nil {
                missedFrom = day
            }
        }

        // An absence still running when the scan ran out of days.
        var openGap: Gap?
        if let began = missedFrom {
            let last = max(yesterday, began)
            let length = (calendar.dateComponents([.day], from: began, to: last).day ?? 0) + 1
            openGap = Gap(
                id: gaps.count,
                missedFrom: began,
                missedTo: last,
                returnedOn: nil,
                length: max(length, 1)
            )
        }

        if !gaps.isEmpty {
            let total = gaps.reduce(0.0) { $0 + Double($1.length) }
            report.averageReturn = total / Double(gaps.count)
        }
        report.returns = gaps.count
        report.longestAbsence = (gaps.map(\.length) + [openGap?.length].compactMap { $0 }).max() ?? 0

        // Only counted while today is unanswered. Once the day is logged there is
        // no absence in progress, whatever happened before it.
        if !kept.contains(today) {
            var away = 0
            var day = yesterday
            while day >= start, !kept.contains(day) {
                away += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
                day = previous
            }
            report.awayNow = away
        }

        report.gaps = gaps.reversed()
        if let openGap { report.gaps.insert(openGap, at: 0) }
        report.columns = columns(for: days, kept: kept, today: today, calendar: calendar)
        return report
    }

    // MARK: - Grid

    /// Week-aligned for `TPHeatmap`, which lays out seven rows per column.
    /// Days outside the record are sent as -1, which the component draws as
    /// nothing at all — the grid should not imply a gap before the log began.
    private static func columns(
        for days: [Date],
        kept: Set<Date>,
        today: Date,
        calendar: Calendar
    ) -> [[Double]] {
        guard let first = days.first, let last = days.last else { return [] }
        guard let gridStart = calendar.dateInterval(of: .weekOfYear, for: first)?.start else { return [] }

        var result: [[Double]] = []
        var weekStart = gridStart

        while weekStart <= last {
            var rows: [Double] = []
            for offset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                    rows.append(-1)
                    continue
                }
                if day > today || day < first {
                    rows.append(-1)
                } else {
                    rows.append(kept.contains(day) ? 1 : 0)
                }
            }
            result.append(rows)
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { break }
            weekStart = next
        }
        return result
    }
}
