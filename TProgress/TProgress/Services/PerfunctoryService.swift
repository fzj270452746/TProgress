import Foundation

// MARK: - Perfunctory service
//
// How the log was written, not how much of it there is.
//
// `HabitService.quickLog` leaves a precise fingerprint — one session, no time,
// no note — which is what makes the one-tap days countable. This counts them and
// says nothing about whether that is good. The tap is the practice: a boring log
// is an honest one, and someone who taps on a bad day is doing the exact thing
// this app was built for.

enum PerfunctoryService {

    struct Bucket: Identifiable {
        let id: String
        let label: String
        let total: Int
        let quick: Int

        var rate: Double { total > 0 ? Double(quick) / Double(total) : 0 }
    }

    struct Report {
        /// Ordinary logs only. Every other kind is excluded by construction, so
        /// choosing the minimum is never counted as a shortcut.
        var total = 0
        var quick = 0
        var rate: Double = 0

        /// Seven, in the calendar's own week order.
        var byWeekday: [Bucket] = []

        /// Five bands of the day, drawn only from entries that carry a real
        /// clock time.
        var byBand: [Bucket] = []
        var timedSample = 0

        var hasAnything: Bool { total > 0 }
        var hasTimedSample: Bool { timedSample > 0 }
    }

    static func report() -> Report {
        report(for: StatsService.joinedCircles())
    }

    static func report(for circles: [CDHabit]) -> Report {
        let calendar = Calendar.current

        // Only the ordinary ones. A minimum is a different thing and says so on
        // the row; a rest or a backfilled day is not an ordinary log at all.
        let entries = circles
            .flatMap(\.checkIns)
            .filter { $0.isMine && $0.kind == .standard }

        var report = Report()
        report.total = entries.count
        report.quick = entries.filter(\.isPerfunctory).count
        report.rate = report.total > 0 ? Double(report.quick) / Double(report.total) : 0

        report.byWeekday = weekdayBuckets(entries, calendar: calendar)

        // Time of day is only readable from rows that carry a real clock time,
        // and the sample data does not. So this is drawn from the days written
        // in the app, and the size of that sample is reported beside it rather
        // than hidden — the page can then say what it is actually based on.
        let timed = entries.filter(\.wasWrittenByHand)
        report.timedSample = timed.count
        report.byBand = bandBuckets(timed, calendar: calendar)

        return report
    }

    // MARK: - Buckets

    private static func weekdayBuckets(_ entries: [CDCheckIn], calendar: Calendar) -> [Bucket] {
        let first = calendar.firstWeekday
        return (0..<7).map { index in
            let weekday = ((first - 1 + index) % 7) + 1
            let onDay = entries.filter { entry in
                guard let date = entry.date else { return false }
                return calendar.component(.weekday, from: date) == weekday
            }
            return Bucket(
                id: "w\(weekday)",
                label: HabitWeekday(rawValue: weekday)?.initial ?? "?",
                total: onDay.count,
                quick: onDay.filter(\.isPerfunctory).count
            )
        }
    }

    private static func bandBuckets(_ entries: [CDCheckIn], calendar: Calendar) -> [Bucket] {
        var totals = Array(repeating: 0, count: TimeBand.allCases.count)
        var quicks = Array(repeating: 0, count: TimeBand.allCases.count)

        for entry in entries {
            guard let stamp = entry.createdAt else { continue }
            guard let band = TimeBand(hour: calendar.component(.hour, from: stamp)) else { continue }
            totals[band.index] += 1
            if entry.isPerfunctory { quicks[band.index] += 1 }
        }

        return TimeBand.allCases.map { band in
            Bucket(
                id: band.rawValue,
                label: band.shortLabel,
                total: totals[band.index],
                quick: quicks[band.index]
            )
        }
    }
}

// MARK: - Time bands
//
// Five slices, broad enough to read at a glance and narrow enough to mean
// something: a practice at six in the morning is a different practice from the
// same one at eleven at night.

enum TimeBand: String, CaseIterable, Identifiable {

    case night, early, morning, afternoon, evening

    var id: String { rawValue }

    var label: String {
        switch self {
        case .night:     return "Night"
        case .early:     return "Early"
        case .morning:   return "Morning"
        case .afternoon: return "Afternoon"
        case .evening:   return "Evening"
        }
    }

    /// A short range for chart labels, where the word will not fit.
    var shortLabel: String {
        switch self {
        case .night:     return "12–5"
        case .early:     return "6–8"
        case .morning:   return "9–11"
        case .afternoon: return "12–4"
        case .evening:   return "5–11"
        }
    }

    var index: Int { TimeBand.allCases.firstIndex(of: self) ?? 0 }

    init?(hour: Int) {
        switch hour {
        case 0..<6:   self = .night
        case 6..<9:   self = .early
        case 9..<12:  self = .morning
        case 12..<17: self = .afternoon
        default:      self = .evening
        }
    }
}
