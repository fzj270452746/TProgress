import Foundation
import CoreData
import SwiftUI

// MARK: - Identity
//
// Core Data's base class does not bring `Identifiable` with it, and every entity
// already carries a stable UUID, so the conformance comes from that.

extension CDUser: Identifiable {}
extension CDPost: Identifiable {}
extension CDMedia: Identifiable {}
extension CDComment: Identifiable {}
extension CDHabit: Identifiable {}
extension CDCheckIn: Identifiable {}
extension CDStageSummary: Identifiable {}
extension CDChallenge: Identifiable {}
extension CDConversation: Identifiable {}
extension CDMessage: Identifiable {}
extension CDGiftEvent: Identifiable {}

// MARK: - Vocabulary

enum PostKind: String, CaseIterable, Identifiable {

    case progress
    case checkIn
    case summary

    var id: String { rawValue }

    var label: String {
        switch self {
        case .progress: return "Progress"
        case .checkIn:  return "Check in"
        case .summary:  return "Recap"
        }
    }

    var symbol: String {
        switch self {
        case .progress: return "chart.line.uptrend.xyaxis"
        case .checkIn:  return "checkmark.circle"
        case .summary:  return "calendar"
        }
    }
}

enum MediaKind: String {
    case image
    case video
}

enum FriendState: String {

    case none
    case requested
    case incoming
    case friends

    var label: String {
        switch self {
        case .none:      return "Add friend"
        case .requested: return "Requested"
        case .incoming:  return "Accept request"
        case .friends:   return "Friends"
        }
    }
}

enum MessageKind: String {
    case text
    case callInvite
    case callDeclined
    case gift
    case checkIn
}

enum MessageStatus: String {
    case sent
    case delivered
    case read
}

/// How often a circle asks you to show up.
///
/// The free-text `cadence` the seed data ships with stays the thing we parse
/// from, so a circle that predates goals still resolves to something sensible
/// the first time it is read.
enum GoalType: String, CaseIterable, Identifiable {

    case daily
    case weeklyCount
    case weekdays

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily:       return "Every day"
        case .weeklyCount: return "Times a week"
        case .weekdays:    return "Set days"
        }
    }

    /// Reads "Daily" / "Nightly" / "Weekdays" / "4× a week" into a goal.
    static func parse(cadence: String?) -> (type: GoalType, count: Int, mask: Int) {
        let text = (cadence ?? "").lowercased()

        if text.contains("weekday") {
            return (.weekdays, 0, HabitWeekday.weekdaysMask)
        }
        let leading = text.prefix { $0.isNumber }
        if let count = Int(leading), count > 0, text.contains("week") {
            return (.weeklyCount, count, 0)
        }
        return (.daily, 0, 0)
    }
}

/// Calendar's own weekday numbering (1 = Sunday), so a value taken from
/// `Calendar.component(.weekday, from:)` can be used without translation.
enum HabitWeekday: Int, CaseIterable, Identifiable {

    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var initial: String {
        ["S", "M", "T", "W", "T", "F", "S"][rawValue - 1]
    }

    var name: String {
        ["Sunday", "Monday", "Tuesday", "Wednesday",
         "Thursday", "Friday", "Saturday"][rawValue - 1]
    }

    /// Bit position: Sunday is bit 0, Saturday bit 6.
    var bit: Int { 1 << (rawValue - 1) }

    static func mask(_ days: some Sequence<HabitWeekday>) -> Int {
        days.reduce(0) { $0 | $1.bit }
    }

    static func mask(containing day: Int) -> Int { 1 << (day - 1) }

    static func contains(_ mask: Int, _ day: HabitWeekday) -> Bool {
        mask & day.bit != 0
    }

    static func days(in mask: Int) -> [HabitWeekday] {
        allCases.filter { contains(mask, $0) }
    }

    static var weekdaysMask: Int { mask([.monday, .tuesday, .wednesday, .thursday, .friday]) }
}

/// The three stages a circle is recapped at.
enum RecapKind: String, CaseIterable, Identifiable {

    case thirtyDay = "d30"
    case sixWeek = "w6"
    case quarter = "quarter"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .thirtyDay: return "30 days"
        case .sixWeek:   return "6 weeks"
        case .quarter:   return "Quarter"
        }
    }

    var days: Int {
        switch self {
        case .thirtyDay: return 30
        case .sixWeek:   return 42
        case .quarter:   return 90
        }
    }
}

/// A circle's shared goal. Neither kind ranks anybody — one counts what the
/// group did together, the other counts days the group kept the chain alive.
enum ChallengeKind: String {

    case collective
    case relay21

    var label: String {
        switch self {
        case .collective: return "Together"
        case .relay21:    return "21-day relay"
        }
    }
}

/// The streak lengths worth stopping for. Freeze cards are handed out here.
enum Milestone {

    static let ladder: [Int] = [3, 7, 14, 21, 30, 50, 75, 100, 150, 200, 365]

    /// The first rung above `value`, or nil when the ladder is topped out.
    static func next(after value: Int) -> Int? {
        ladder.first { $0 > value }
    }

    /// The highest rung `value` has reached, or nil below the first one.
    static func reached(upTo value: Int) -> Int? {
        ladder.last { $0 <= value }
    }

    /// Rungs crossed between two streak values — used to grant retroactively
    /// when a streak jumps by more than one rung at once.
    static func crossed(from old: Int, to new: Int) -> [Int] {
        ladder.filter { $0 > old && $0 <= new }
    }
}

// MARK: - User

@objc(CDUser)
final class CDUser: NSManagedObject {

    @NSManaged var id: UUID?
    @NSManaged var username: String?
    @NSManaged var displayName: String?
    @NSManaged var bio: String?
    @NSManaged var avatarAssetName: String?
    @NSManaged var avatarSeed: Int64
    @NSManaged var joinedAt: Date?
    @NSManaged var streak: Int32
    @NSManaged var totalCheckIns: Int32
    @NSManaged var isCurrentUser: Bool
    @NSManaged var isFollowedByMe: Bool
    @NSManaged var followsMe: Bool
    @NSManaged var friendStateRaw: String?
    @NSManaged var isBlocked: Bool
    @NSManaged var longestStreak: Int32
    @NSManaged var lastCheckInDay: Date?

    /// Freeze cards are earned, never bought. `lastMilestoneAwarded` and
    /// `lastPerfectWeekAwardedAt` are the high-water marks that keep a grant
    /// from being handed out twice.
    @NSManaged var freezeTokens: Int32
    @NSManaged var lastMilestoneAwarded: Int32
    @NSManaged var lastPerfectWeekAwardedAt: Date?

    @NSManaged var posts: Set<CDPost>
    @NSManaged var comments: Set<CDComment>
    @NSManaged var giftsSent: Set<CDGiftEvent>
    @NSManaged var conversation: CDConversation?
}

extension CDUser {

    var friendState: FriendState {
        get { FriendState(rawValue: friendStateRaw ?? "") ?? .none }
        set { friendStateRaw = newValue.rawValue }
    }

    var isFriend: Bool { friendState == .friends }

    var name: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return username ?? "Someone"
    }

    var handle: String { "@" + (username ?? "unknown") }

    var bioText: String {
        if let bio, !bio.isEmpty { return bio }
        return "Showing up, one small thing at a time."
    }

    var joinedLabel: String {
        guard let joinedAt else { return "Recently joined" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return "Joined " + formatter.string(from: joinedAt)
    }

    var sortedPosts: [CDPost] {
        posts.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    var postCount: Int { posts.count }

    /// The signed-in account counts real rows. Everyone else keeps a derived
    /// number, because the seeded community carries no follower rows of its own
    /// and a profile with "0 followers" reads as broken rather than honest.
    var followerCount: Int {
        guard isCurrentUser else {
            return Int(truncatingIfNeeded: avatarSeed % 480) + 12
        }
        return CoreDataStack.shared.count(
            CDUser.self,
            predicate: NSPredicate(format: "followsMe == YES AND isCurrentUser == NO")
        )
    }

    var followingCount: Int {
        guard isCurrentUser else {
            return Int(truncatingIfNeeded: (avatarSeed / 7) % 220) + 8
        }
        return CoreDataStack.shared.count(
            CDUser.self,
            predicate: NSPredicate(format: "isFollowedByMe == YES AND isCurrentUser == NO")
        )
    }

    var hasFreezeCards: Bool { freezeTokens > 0 }

    /// The highest rung the current streak has reached, if any.
    var reachedMilestone: Int? { Milestone.reached(upTo: Int(streak)) }

    /// The rung being worked toward and how far along it is, for the badge.
    var milestoneProgress: (next: Int, ratio: Double)? {
        let current = Int(streak)
        guard let next = Milestone.next(after: current) else { return nil }
        let floor = Milestone.reached(upTo: current) ?? 0
        let span = Double(next - floor)
        guard span > 0 else { return nil }
        return (next, min(1, Double(current - floor) / span))
    }
}

// MARK: - Post

@objc(CDPost)
final class CDPost: NSManagedObject {

    @NSManaged var id: UUID?
    @NSManaged var text: String?
    @NSManaged var createdAt: Date?
    @NSManaged var kindRaw: String?
    @NSManaged var topicTag: String?
    @NSManaged var likeCount: Int32
    @NSManaged var giftCount: Int32
    @NSManaged var isLikedByMe: Bool
    @NSManaged var isMine: Bool
    @NSManaged var durationMinutes: Int32
    @NSManaged var amountValue: Double
    @NSManaged var amountUnit: String?
    @NSManaged var habitName: String?
    @NSManaged var seed: Int64

    @NSManaged var author: CDUser?
    @NSManaged var habit: CDHabit?
    @NSManaged var media: Set<CDMedia>
    @NSManaged var comments: Set<CDComment>
    @NSManaged var gifts: Set<CDGiftEvent>
}

extension CDPost {

    /// The circle this post was tagged to. `habitName` stays as the fallback so
    /// posts written before the relationship existed still show their tag.
    var habitTitle: String? {
        habit?.title ?? habitName
    }

    var kind: PostKind {
        get { PostKind(rawValue: kindRaw ?? "") ?? .progress }
        set { kindRaw = newValue.rawValue }
    }

    var body: String { text ?? "" }

    var sortedMedia: [CDMedia] {
        media.sorted { $0.order < $1.order }
    }

    var sortedComments: [CDComment] {
        comments.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    var commentCount: Int { comments.count }

    /// "5 pages", "10 min" — the concrete unit of work the community rewards.
    var quantityLabel: String? {
        guard amountValue > 0 else {
            return durationMinutes > 0 ? "\(durationMinutes) min" : nil
        }
        let value = amountValue.rounded() == amountValue
            ? String(Int(amountValue))
            : String(format: "%.1f", amountValue)
        let unit = amountUnit ?? ""
        return unit.isEmpty ? value : "\(value) \(unit)"
    }

    /// `quantityLabel` split into its figure and its unit, so a layout can set
    /// the figure at display size and hang the unit beside it. "5 pages"
    /// becomes "5" + "pages".
    var quantityParts: (value: String, unit: String)? {
        guard let label = quantityLabel else { return nil }
        let parts = label.split(separator: " ", maxSplits: 1)
        guard let figure = parts.first else { return nil }
        return (String(figure), parts.count > 1 ? String(parts[1]) : "")
    }

    var relativeTime: String { TPTime.relative(from: createdAt) }

    var hasMedia: Bool { !media.isEmpty }

    var firstVideo: CDMedia? { sortedMedia.first { $0.kind == .video } }
}

// MARK: - Media

@objc(CDMedia)
final class CDMedia: NSManagedObject {

    @NSManaged var id: UUID?
    @NSManaged var kindRaw: String?
    @NSManaged var assetName: String?
    @NSManaged var thumbnailName: String?
    @NSManaged var caption: String?
    @NSManaged var durationSeconds: Double
    @NSManaged var order: Int32
    @NSManaged var seed: Int64

    @NSManaged var post: CDPost?
}

extension CDMedia {

    var kind: MediaKind {
        get { MediaKind(rawValue: kindRaw ?? "") ?? .image }
        set { kindRaw = newValue.rawValue }
    }

    var isVideo: Bool { kind == .video }

    /// Ratio of height to width, used by the waterfall layout.
    var aspectRatio: CGFloat {
        let ratios: [CGFloat] = [1.0, 1.25, 0.75, 1.4, 0.85, 1.15]
        return ratios[Int(truncatingIfNeeded: seed % Int64(ratios.count))]
    }

    /// The seeded length. A row whose clip actually ships reports its real
    /// length instead — see `TPMediaTile`.
    var durationLabel: String? {
        guard isVideo, durationSeconds > 0 else { return nil }
        return TPMediaLibrary.label(forDuration: durationSeconds)
    }
}

// MARK: - Comment

@objc(CDComment)
final class CDComment: NSManagedObject {

    @NSManaged var id: UUID?
    @NSManaged var text: String?
    @NSManaged var createdAt: Date?
    @NSManaged var likeCount: Int32
    @NSManaged var isLikedByMe: Bool
    @NSManaged var isMine: Bool

    @NSManaged var author: CDUser?
    @NSManaged var post: CDPost?
}

extension CDComment {

    var body: String { text ?? "" }
    var relativeTime: String { TPTime.relative(from: createdAt) }
}

// MARK: - Habit circle

@objc(CDHabit)
final class CDHabit: NSManagedObject {

    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var blurb: String?
    @NSManaged var iconKey: String?
    @NSManaged var accentIndex: Int32
    @NSManaged var memberCount: Int32
    @NSManaged var isJoined: Bool
    @NSManaged var cadence: String?
    @NSManaged var category: String?
    @NSManaged var todayChecked: Bool
    @NSManaged var progress: Double
    @NSManaged var streak: Int32
    @NSManaged var totalMinutes: Int32
    @NSManaged var seed: Int64

    @NSManaged var goalTypeRaw: String?
    @NSManaged var goalCount: Int32
    @NSManaged var goalWeekdays: Int32
    @NSManaged var goalAmount: Double
    @NSManaged var goalUnit: String?

    @NSManaged var checkIns: Set<CDCheckIn>
    @NSManaged var summaries: Set<CDStageSummary>
    @NSManaged var posts: Set<CDPost>
    @NSManaged var challenges: Set<CDChallenge>
}

extension CDHabit {

    var title: String { name ?? "Untitled circle" }
    var subtitle: String { blurb ?? "" }
    var accent: Color { .tpAccent(Int(accentIndex)) }
    var cadenceLabel: String { cadence ?? "Daily" }
    var categoryLabel: String { category ?? "General" }

    // MARK: Goal
    //
    // A circle that predates goals has no `goalTypeRaw`, so every read falls
    // back to parsing the `cadence` text it was seeded with. That is what makes
    // the upgrade land without a migration script.

    var goalType: GoalType {
        get {
            if let raw = goalTypeRaw, let parsed = GoalType(rawValue: raw) { return parsed }
            return GoalType.parse(cadence: cadence).type
        }
        set { goalTypeRaw = newValue.rawValue }
    }

    var goalTarget: Int {
        get {
            if goalCount > 0 { return Int(goalCount) }
            return GoalType.parse(cadence: cadence).count
        }
        set { goalCount = Int32(newValue) }
    }

    var goalWeekdayMask: Int {
        goalWeekdays > 0 ? Int(goalWeekdays) : GoalType.parse(cadence: cadence).mask
    }

    var goalDays: [HabitWeekday] { HabitWeekday.days(in: goalWeekdayMask) }

    /// The goal restated the way it was asked for: "Every day", "4× a week",
    /// "M W F".
    var goalLabel: String {
        switch goalType {
        case .daily:
            return "Every day"
        case .weeklyCount:
            let target = goalTarget
            return target > 0 ? "\(target)× a week" : "Every week"
        case .weekdays:
            let days = goalDays
            if days.isEmpty { return "Some days" }
            if days == HabitWeekday.days(in: HabitWeekday.weekdaysMask) { return "Weekdays" }
            return days.map(\.initial).joined(separator: " ")
        }
    }

    /// Whether the goal asks for anything today.
    var isScheduledToday: Bool {
        switch goalType {
        case .daily, .weeklyCount:
            return true
        case .weekdays:
            let weekday = Calendar.current.component(.weekday, from: Date())
            return HabitWeekday.contains(goalWeekdayMask, HabitWeekday(rawValue: weekday) ?? .sunday)
        }
    }

    /// How much of the goal the current period covers, 0...1. Daily and
    /// weekday goals read the day; a weekly goal counts logged days inside the
    /// current calendar week.
    var goalProgress: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let logged = Set(checkIns.map { calendar.startOfDay(for: $0.date ?? .distantPast) })

        switch goalType {
        case .daily, .weekdays:
            guard isScheduledToday else { return 1 }
            return logged.contains(today) ? 1 : 0

        case .weeklyCount:
            let target = max(goalTarget, 1)
            guard let week = calendar.dateInterval(of: .weekOfYear, for: today) else { return 0 }
            let hits = logged.filter { $0 >= week.start && $0 <= today }.count
            return min(1, Double(hits) / Double(target))
        }
    }

    /// Consecutive logged days ending today. A day that has not been logged yet
    /// does not break the run, so the count is read from yesterday when today
    /// is still empty.
    var computedStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let logged = Set(checkIns.map { calendar.startOfDay(for: $0.date ?? .distantPast) })
        guard !logged.isEmpty else { return 0 }

        var cursor = logged.contains(today)
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today) ?? today

        var count = 0
        while logged.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    var sortedPosts: [CDPost] {
        posts.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    var activeChallenges: [CDChallenge] {
        challenges
            .filter { ($0.endDate ?? .distantPast) >= Date() }
            .sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
    }

    var symbol: String { iconKey ?? "circle" }

    /// Catalogue art for this circle, when the artwork pack provides it.
    /// `circle_deep_reading`, `circle_morning_pages`, and so on.
    var iconAssetName: String {
        "circle_" + title
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
    }

    var sortedCheckIns: [CDCheckIn] {
        checkIns.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    var latestSummary: CDStageSummary? {
        summaries.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }.first
    }

    /// Last seven days as 0...1 completion, oldest first, today last.
    var weekValues: [Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let logged = Set(checkIns.compactMap { $0.date.map { calendar.startOfDay(for: $0) } })

        return (0..<7).reversed().map { offset -> Double in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return 0 }
            return logged.contains(day) ? 1 : 0
        }
    }

    /// The same seven days, weighted by how much was logged and normalised
    /// against the week's peak. Showing up always registers; a light day still
    /// draws a short bar, which makes the strip a record rather than a switch.
    var weekAmounts: [Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var totals: [Date: Double] = [:]
        for entry in checkIns {
            guard let date = entry.date else { continue }
            let day = calendar.startOfDay(for: date)
            totals[day, default: 0] += max(entry.amountValue, 1)
        }

        let values = (0..<7).reversed().map { offset -> Double in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return 0 }
            return totals[day] ?? 0
        }

        guard let peak = values.max(), peak > 0 else { return values }
        return values.map { $0 > 0 ? max(0.30, $0 / peak) : 0 }
    }
}

// MARK: - Challenge

@objc(CDChallenge)
final class CDChallenge: NSManagedObject {

    @NSManaged var id: UUID?
    @NSManaged var title: String?
    @NSManaged var blurb: String?
    @NSManaged var kindRaw: String?
    @NSManaged var startDate: Date?
    @NSManaged var endDate: Date?
    @NSManaged var targetValue: Double
    @NSManaged var unit: String?
    @NSManaged var isJoined: Bool
    @NSManaged var seed: Int64

    @NSManaged var habit: CDHabit?
}

extension CDChallenge {

    var kind: ChallengeKind {
        get { ChallengeKind(rawValue: kindRaw ?? "") ?? .collective }
        set { kindRaw = newValue.rawValue }
    }

    var heading: String { title ?? "Challenge" }
    var blurbText: String { blurb ?? "" }
    var accent: Color { habit?.accent ?? .tpEmber }

    var totalDays: Int {
        guard let startDate, let endDate else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return max(days, 1)
    }

    var daysRemaining: Int {
        guard let endDate else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: endDate)
        return max(calendar.dateComponents([.day], from: today, to: end).day ?? 0, 0)
    }

    var isActive: Bool {
        guard let startDate, let endDate else { return false }
        let now = Date()
        return now >= startDate && now <= endDate
    }

    var target: Double {
        if targetValue > 0 { return targetValue }
        return kind == .relay21 ? Double(min(totalDays, 21)) : Double(totalDays)
    }

    /// Days inside the window the signed-in account logged this circle. This is
    /// the half of the bar that is actually earned.
    var myDays: Int {
        guard let habit else { return 0 }
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: startDate ?? .distantPast)
        let to = calendar.startOfDay(for: endDate ?? .distantFuture)
        return habit.checkIns
            .filter(\.isMine)
            .compactMap(\.date)
            .map { calendar.startOfDay(for: $0) }
            .filter { $0 >= from && $0 <= to }
            .count
    }

    /// Days the rest of the circle covered, derived from the challenge seed so
    /// it stays stable across launches — the same convention the community's
    /// other counts use. The account's own contribution stays real.
    private var groupDays: Int {
        var generator = SeededGenerator(seed: seed)
        let span = totalDays
        guard span > 0 else { return 0 }
        let share = Double.random(in: 0.35...0.72, using: &generator)
        return Int((Double(span) * share).rounded())
    }

    var covered: Int { groupDays + myDays }

    /// Combined coverage 0...1. Deliberately not a ranking: it is one bar the
    /// whole circle fills, which is what a shared practice is.
    var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(covered) / target)
    }

    var progressLabel: String {
        "\(covered) of \(Int(target)) \(unit ?? "days")"
    }

    /// Per-day coverage for the relay strip.
    var coveredDays: [Bool] {
        guard let habit, let startDate, let endDate, totalDays > 0 else { return [] }
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: startDate)
        let to = calendar.startOfDay(for: endDate)

        let mine = Set(
            habit.checkIns
                .filter(\.isMine)
                .compactMap { $0.date.map { calendar.startOfDay(for: $0) } }
        )

        var generator = SeededGenerator(seed: seed &+ 7919)
        return (0..<totalDays).map { index in
            guard let day = calendar.date(byAdding: .day, value: index, to: from), day <= to else {
                return false
            }
            if mine.contains(day) { return true }
            return Double.random(in: 0...1, using: &generator) < 0.62
        }
    }
}

// MARK: - Check in

@objc(CDCheckIn)
final class CDCheckIn: NSManagedObject {

    @NSManaged var id: UUID?
    @NSManaged var date: Date?
    @NSManaged var note: String?
    @NSManaged var amountValue: Double
    @NSManaged var amountUnit: String?
    @NSManaged var isMine: Bool
    @NSManaged var durationMinutes: Int32

    /// Set on a day a freeze card bought back. It keeps the day in the streak
    /// without letting it inflate the effort numbers.
    @NSManaged var isFreeze: Bool

    @NSManaged var habit: CDHabit?
}

extension CDCheckIn {

    var noteText: String { note ?? "" }
    var relativeTime: String { TPTime.relative(from: date) }

    var hasNote: Bool { !noteText.isEmpty }

    var day: Date { Calendar.current.startOfDay(for: date ?? .distantPast) }

    /// "12 pages", "30 min", "1 session" — whatever was actually logged.
    var amountLabel: String {
        let value = amountValue.rounded() == amountValue
            ? String(Int(amountValue))
            : String(format: "%.1f", amountValue)
        let unit = amountUnit ?? ""
        return "\(value) \(unit)".trimmingCharacters(in: .whitespaces)
    }

    var durationLabel: String? {
        guard durationMinutes > 0 else { return nil }
        return durationMinutes >= 60
            ? String(format: "%.1fh", Double(durationMinutes) / 60)
            : "\(durationMinutes)m"
    }
}

// MARK: - Stage summary

@objc(CDStageSummary)
final class CDStageSummary: NSManagedObject {

    @NSManaged var id: UUID?
    @NSManaged var title: String?
    @NSManaged var reflection: String?
    @NSManaged var periodStart: Date?
    @NSManaged var periodEnd: Date?
    @NSManaged var completionRate: Double
    @NSManaged var totalValue: Double
    @NSManaged var unit: String?
    @NSManaged var createdAt: Date?
    @NSManaged var seed: Int64
    @NSManaged var kindRaw: String?

    @NSManaged var habit: CDHabit?
}

extension CDStageSummary {

    /// nil on the three summaries the seed ships with; the ones the app writes
    /// itself carry the cadence that produced them.
    var kind: RecapKind? {
        get { kindRaw.flatMap(RecapKind.init(rawValue:)) }
        set { kindRaw = newValue?.rawValue }
    }

    var isAutomatic: Bool { kind != nil }

    var heading: String { title ?? "Stage recap" }
    var reflectionText: String { reflection ?? "" }

    var periodLabel: String {
        guard let periodStart, let periodEnd else { return "This period" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: periodStart)) – \(formatter.string(from: periodEnd))"
    }

    var totalLabel: String {
        let value = totalValue.rounded() == totalValue
            ? String(Int(totalValue))
            : String(format: "%.1f", totalValue)
        return "\(value) \(unit ?? "")".trimmingCharacters(in: .whitespaces)
    }

    /// The six point trend the recap chart draws, as consistency 0...1.
    ///
    /// Read from the circle's own log across the summary's period rather than
    /// invented from its seed, so the chart moves when the log does. The
    /// deterministic fallback is kept only for a summary whose period holds no
    /// check-ins at all.
    var trendValues: [Double] {
        let bucketCount = 6
        guard let habit, let start = periodStart, let end = periodEnd, end > start else {
            return fallbackTrend
        }

        let calendar = Calendar.current
        let logged = Set(
            habit.checkIns
                .filter(\.isMine)
                .compactMap { $0.date.map { calendar.startOfDay(for: $0) } }
        )
        guard !logged.isEmpty else { return fallbackTrend }

        let span = end.timeIntervalSince(start) / Double(bucketCount)
        guard span > 0 else { return fallbackTrend }

        return (0..<bucketCount).map { index in
            let bucketStart = start.addingTimeInterval(span * Double(index))
            let bucketEnd = start.addingTimeInterval(span * Double(index + 1))
            let from = calendar.startOfDay(for: bucketStart)
            let to = calendar.startOfDay(for: bucketEnd)
            let days = max(calendar.dateComponents([.day], from: from, to: to).day ?? 0, 1)
            let hits = logged.filter { $0 >= from && $0 < to }.count
            return min(1, Double(hits) / Double(days))
        }
    }

    /// Used only when a period holds nothing to read.
    private var fallbackTrend: [Double] {
        var generator = SeededGenerator(seed: seed)
        let base = max(completionRate, 0.25)
        return (0..<6).map { index in
            let noise = Double.random(in: -0.18...0.20, using: &generator)
            let slope = Double(index) * 0.05
            return min(max(base + noise + slope - 0.12, 0.06), 1.0)
        }
    }

    var trendLabels: [String] {
        ["W1", "W2", "W3", "W4", "W5", "W6"]
    }
}

// MARK: - Conversation

@objc(CDConversation)
final class CDConversation: NSManagedObject {

    @NSManaged var id: UUID?
    @NSManaged var lastMessageText: String?
    @NSManaged var lastMessageAt: Date?
    @NSManaged var unreadCount: Int32
    @NSManaged var isMuted: Bool

    @NSManaged var peer: CDUser?
    @NSManaged var messages: Set<CDMessage>
}

extension CDConversation {

    var preview: String { lastMessageText ?? "Say hello" }
    var relativeTime: String { TPTime.relative(from: lastMessageAt) }
    var hasUnread: Bool { unreadCount > 0 }

    var sortedMessages: [CDMessage] {
        messages.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    var lastMessage: CDMessage? { sortedMessages.last }
}

// MARK: - Message

@objc(CDMessage)
final class CDMessage: NSManagedObject {

    @NSManaged var id: UUID?
    @NSManaged var text: String?
    @NSManaged var createdAt: Date?
    @NSManaged var isMine: Bool
    @NSManaged var kindRaw: String?
    @NSManaged var statusRaw: String?
    @NSManaged var linkPostID: UUID?

    @NSManaged var conversation: CDConversation?
}

extension CDMessage {

    var kind: MessageKind {
        get { MessageKind(rawValue: kindRaw ?? "") ?? .text }
        set { kindRaw = newValue.rawValue }
    }

    var status: MessageStatus {
        get { MessageStatus(rawValue: statusRaw ?? "") ?? .sent }
        set { statusRaw = newValue.rawValue }
    }

    var body: String { text ?? "" }
    var relativeTime: String { TPTime.relative(from: createdAt) }
    var timeLabel: String { TPTime.clock(from: createdAt) }
}

// MARK: - Gift event

@objc(CDGiftEvent)
final class CDGiftEvent: NSManagedObject {

    @NSManaged var id: UUID?
    @NSManaged var giftKey: String?
    @NSManaged var productID: String?
    @NSManaged var priceCents: Int32
    @NSManaged var createdAt: Date?

    @NSManaged var post: CDPost?
    @NSManaged var sender: CDUser?
}

extension CDGiftEvent {

    var gift: TPGift? { TPGiftCatalog.gift(for: giftKey ?? "") }
    var relativeTime: String { TPTime.relative(from: createdAt) }
}
