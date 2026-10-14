import Foundation
import CoreData

// MARK: - Challenge service
//
// A circle's shared goal. Deliberately not a leaderboard — `CirclesView` has
// carried the line "a circle is a shared practice, not a leaderboard" since the
// beginning, and this is built to honour it: one bar the whole circle fills,
// plus a list of who is in, with no ordering by score and no rank.

enum ChallengeService {

    private static var context: NSManagedObjectContext { CoreDataStack.shared.context }

    // MARK: - Reading

    static func all() -> [CDChallenge] {
        CoreDataStack.shared.fetch(
            CDChallenge.self,
            sortBy: [NSSortDescriptor(key: "endDate", ascending: false)]
        )
    }

    static func active() -> [CDChallenge] {
        all()
            .filter(\.isActive)
            .sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
    }

    static func forHabit(_ habit: CDHabit) -> [CDChallenge] {
        habit.challenges
            .sorted { ($0.endDate ?? .distantPast) > ($1.endDate ?? .distantPast) }
    }

    static func open(of habit: CDHabit) -> CDChallenge? {
        forHabit(habit).first { $0.isActive }
    }

    static func joined() -> [CDChallenge] {
        active().filter(\.isJoined)
    }

    // MARK: - Joining

    static func join(_ challenge: CDChallenge) {
        guard !challenge.isJoined else { return }
        challenge.isJoined = true
        CoreDataStack.shared.save()
    }

    static func leave(_ challenge: CDChallenge) {
        guard challenge.isJoined else { return }
        challenge.isJoined = false
        CoreDataStack.shared.save()
    }

    // MARK: - People

    /// Who is in the circle, with a derived number of days each has covered.
    /// The signed-in account's own days are counted from its log; everyone
    /// else's come from the challenge seed, the same convention the rest of the
    /// community's numbers use.
    ///
    /// Never sorted by the number — the list is alphabetical and the figure is
    /// context, not a position.
    static func participants(_ challenge: CDChallenge, limit: Int = 8) -> [(user: CDUser, days: Int)] {
        guard let habit = challenge.habit else { return [] }

        let others = CoreDataStack.shared.fetch(
            CDUser.self,
            predicate: NSPredicate(format: "isCurrentUser == NO AND isBlocked == NO"),
            sortBy: [TPSort.byDisplayName]
        )

        var generator = SeededGenerator(seed: challenge.seed &+ 104_729)
        let span = max(challenge.totalDays, 1)

        var rows: [(CDUser, Int)] = others.prefix(limit).map { user in
            let share = Double.random(in: 0.15...0.85, using: &generator)
            return (user, Int((Double(span) * share).rounded()))
        }

        if let me = AppSession.shared.currentUser, me.isCurrentUser {
            rows.insert((me, challenge.myDays), at: 0)
        }

        return rows.map { (user: $0.0, days: $0.1) }
    }

    // MARK: - Seeding

    /// Gives every joined circle one running challenge. Written as a backfill
    /// rather than seed data so circles that already existed get one too.
    static func seedIfNeeded() {
        let joined = CoreDataStack.shared.fetch(
            CDHabit.self,
            predicate: NSPredicate(format: "isJoined == YES")
        )
        guard !joined.isEmpty else { return }

        let existing = Set(all().compactMap { $0.habit?.objectID })
        let missing = joined.filter { !existing.contains($0.objectID) }
        guard !missing.isEmpty else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for habit in missing {
            let challenge = CDChallenge(context: context)
            challenge.id = UUID()
            challenge.habit = habit
            challenge.seed = habit.seed &+ 613
            challenge.isJoined = true

            // Circles that ask for something every day get the relay; the rest
            // get a shared tally, which suits a goal counted in sessions.
            if habit.goalType == .daily {
                challenge.kind = .relay21
                challenge.title = "21-day relay"
                challenge.blurb = "One day at a time, passed round the circle. Twenty-one days without the chain breaking."
                challenge.targetValue = 21
                challenge.unit = "days"
                challenge.startDate = calendar.date(byAdding: .day, value: -9, to: today)
                challenge.endDate = calendar.date(byAdding: .day, value: 12, to: today)
            } else {
                challenge.kind = .collective
                let target = Double(60 + Int(habit.seed % 60))
                challenge.title = "Together: \(Int(target)) sessions"
                challenge.blurb = "Not a race. The bar fills as the circle logs, and it fills for everyone at once."
                challenge.targetValue = target
                challenge.unit = "sessions"
                challenge.startDate = calendar.date(byAdding: .day, value: -14, to: today)
                challenge.endDate = calendar.date(byAdding: .day, value: 16, to: today)
            }
        }

        CoreDataStack.shared.save()
    }
}
