import Foundation

/// One place for every relative timestamp, so the feed, the thread and the
/// recap all read the same way.
enum TPTime {

    static func relative(from date: Date?) -> String {
        guard let date else { return "" }
        let seconds = Date().timeIntervalSince(date)

        if seconds < 45 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h" }

        let calendar = Calendar.current
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let days = Int(seconds / 86_400)
        if days < 7 { return "\(days)d" }

        let formatter = DateFormatter()
        formatter.dateFormat = calendar.isDate(date, equalTo: Date(), toGranularity: .year)
            ? "MMM d"
            : "MMM d, yyyy"
        return formatter.string(from: date)
    }

    static func clock(from date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    /// Groups a day heading for the message thread.
    static func dayHeading(from date: Date?) -> String {
        guard let date else { return "" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    static func shouldShowDaySeparator(previous: Date?, current: Date?) -> Bool {
        guard let current else { return false }
        guard let previous else { return true }
        return !Calendar.current.isDate(previous, inSameDayAs: current)
    }

    static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    static func hoursAgo(_ hours: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date()
    }

    static func minutesAgo(_ minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: -minutes, to: Date()) ?? Date()
    }
}
