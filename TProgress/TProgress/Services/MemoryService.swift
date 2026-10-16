import Foundation

// MARK: - Memory service
//
// What was written on this day a year, a month and a week ago.
//
// The lookbacks are offered in order and only the ones with something behind
// them are returned. Early on that is the week alone — the record only reaches
// back as far as the account does — and the page says so rather than printing
// three empty cards in a row. That honesty is the feature: the log fills in as
// it ages, and knowing where it currently starts is part of reading it.

enum MemoryService {

    struct Echo: Identifiable {
        let id: String
        /// "A year ago today"
        let label: String
        let date: Date
        let entries: [CDCheckIn]

        var notes: [String] { entries.map(\.noteText).filter { !$0.isEmpty } }
    }

    struct Report {
        var echoes: [Echo] = []

        var earliestDay: Date?
        var loggedDays = 0
        var spanDays = 0

        var hasAnything: Bool { !echoes.isEmpty }
    }

    /// The lookbacks, longest first, so the page reads backwards in time.
    private static let offsets: [(id: String, label: String, component: Calendar.Component, value: Int)] = [
        ("1y",  "A year ago today",  .year,       -1),
        ("1mo", "A month ago today", .month,      -1),
        ("1w",  "A week ago today",  .weekOfYear, -1),
    ]

    static func report(now: Date = Date()) -> Report {
        report(for: StatsService.joinedCircles(), now: now)
    }

    static func report(for circles: [CDHabit], now: Date = Date()) -> Report {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        let mine = circles.flatMap(\.checkIns).filter(\.isMine)

        var report = Report()

        let days = Set(mine.compactMap { $0.date.map { calendar.startOfDay(for: $0) } })
        report.loggedDays = days.count
        report.earliestDay = days.min()

        if let earliest = report.earliestDay {
            report.spanDays = (calendar.dateComponents([.day], from: earliest, to: today).day ?? 0) + 1
        }

        var echoes: [Echo] = []
        for offset in offsets {
            guard let day = calendar.date(
                byAdding: offset.component,
                value: offset.value,
                to: today
            ) else { continue }

            let target = calendar.startOfDay(for: day)

            var onDay: [CDCheckIn] = []
            for entry in mine {
                guard let date = entry.date else { continue }
                if calendar.startOfDay(for: date) == target {
                    onDay.append(entry)
                }
            }
            onDay.sort { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }

            guard !onDay.isEmpty else { continue }
            echoes.append(Echo(id: offset.id, label: offset.label, date: target, entries: onDay))
        }
        report.echoes = echoes

        return report
    }
}
