import Foundation
import CoreData

// MARK: - Backfill
//
// `Seeder.seedIfNeeded()` only runs on a store with no users at all, so anyone
// who already had the app gets none of the data a new version introduces. This
// fills those gaps instead. Every step guards on the work still being undone,
// which makes the whole pass safe to run on every launch.
//
// Matching is always by a stable business key — `username`, a circle's `name` —
// never by `id`, because the seeder mints fresh UUIDs on every install.

enum Backfill {

    private static var context: NSManagedObjectContext { CoreDataStack.shared.context }

    static func runIfNeeded() {
        removeLegacyRecaps()
        // Runs first: everything downstream reads the kind this writes down.
        materialiseCheckInKinds()
        backfillChallengeJoinDates()
        backfillGoals()
        backfillPostCircles()
        backfillDurations()
        settleCircles()
        settleAccount()

        // Recaps read the goals, so they are rebuilt after those are in place.
        // Running every launch keeps the three periods describing the last 30
        // days, six weeks and quarter rather than whenever they were written.
        RecapService.syncAllJoined()

        // Circles that were joined before challenges existed get one here, and
        // a circle joined later gets one on the next launch.
        ChallengeService.seedIfNeeded()

        // A week can complete while the app is closed, so the payout is checked
        // on the way in as well as after a log.
        HabitService.grantPerfectWeekIfEarned()
    }

    // MARK: - Kinds

    /// Rows written before the log gained a vocabulary carry no `kindRaw`, and a
    /// predicate cannot read a computed property — so the fallback that
    /// `CDCheckIn.kind` performs in Swift is written down once, permanently, to
    /// keep queries reliable.
    ///
    /// The setter writes `isFreeze` back to the value it already held, so this
    /// pass is idempotent and changes nothing about how the rows behave: a
    /// bought-back day keeps its snowflake, and everything else was a plain log.
    private static func materialiseCheckInKinds() {
        let pending = CoreDataStack.shared.fetch(
            CDCheckIn.self,
            predicate: NSPredicate(format: "kindRaw == nil")
        )
        guard !pending.isEmpty else { return }

        for entry in pending {
            entry.kind = entry.isFreeze ? .freeze : .standard
        }
        CoreDataStack.shared.save()
    }

    // MARK: - Challenge join dates

    /// A challenge this account was already in when the field arrived has no join
    /// moment on record. It was there from the start, which is what the start
    /// line should say — rather than inventing a later day and being wrong.
    private static func backfillChallengeJoinDates() {
        let pending = CoreDataStack.shared.fetch(
            CDChallenge.self,
            predicate: NSPredicate(format: "joinedAt == nil")
        )
        guard !pending.isEmpty else { return }

        for challenge in pending {
            challenge.joinedAt = challenge.startDate ?? Date()
        }
        CoreDataStack.shared.save()
    }

    // MARK: - Goals

    /// Circles seeded before goals existed carry only free text — "Daily",
    /// "Weekdays", "4× a week". Parsing it into the structured fields is what
    /// gives the completion rate something real to compute on day one.
    private static func backfillGoals() {
        let pending = CoreDataStack.shared.fetch(
            CDHabit.self,
            predicate: NSPredicate(format: "goalTypeRaw == nil")
        )
        guard !pending.isEmpty else { return }

        for habit in pending {
            let parsed = GoalType.parse(cadence: habit.cadence)
            habit.goalType = parsed.type
            habit.goalCount = Int32(parsed.count)
            habit.goalWeekdays = Int32(parsed.mask)
        }
        CoreDataStack.shared.save()
    }

    // MARK: - Posts

    /// Posts used to reference their circle by name only. Now that the
    /// relationship exists, point each one at the circle it named.
    private static func backfillPostCircles() {
        let pending = CoreDataStack.shared.fetch(
            CDPost.self,
            predicate: NSPredicate(format: "habitName != nil AND habit == nil")
        )
        guard !pending.isEmpty else { return }

        var circlesByName: [String: CDHabit] = [:]
        for habit in CoreDataStack.shared.fetch(CDHabit.self) {
            circlesByName[habit.title] = habit
        }

        for post in pending {
            guard let name = post.habitName, let circle = circlesByName[name] else { continue }
            post.habit = circle
        }
        CoreDataStack.shared.save()
    }

    // MARK: - Recaps

    /// The seed wrote three recaps per circle with hardcoded completion rates
    /// and a trend drawn from a random generator. `RecapService` now derives the
    /// same three periods from the log, so the originals are superseded: leaving
    /// them in place made the circle page list two of everything, one of them
    /// invented.
    private static func removeLegacyRecaps() {
        let legacy = CoreDataStack.shared.fetch(
            CDStageSummary.self,
            predicate: NSPredicate(format: "kindRaw == nil")
        )
        guard !legacy.isEmpty else { return }

        for summary in legacy {
            context.delete(summary)
        }
        CoreDataStack.shared.save()
    }

    // MARK: - Durations

    /// Entries logged before the duration column existed still say how long the
    /// session ran when they were measured in minutes — that number was just
    /// filed under the amount. Reading it back is a repair, not an invention,
    /// and it is what keeps a circle's "time logged" stat from reading zero.
    private static func backfillDurations() {
        let pending = CoreDataStack.shared.fetch(
            CDCheckIn.self,
            predicate: NSPredicate(format: "durationMinutes == 0 AND amountUnit == %@", "min")
        )
        guard !pending.isEmpty else { return }

        for entry in pending {
            entry.durationMinutes = Int32(max(entry.amountValue, 0).rounded())
        }
        CoreDataStack.shared.save()
    }

    // MARK: - Counters

    /// Rewrites the counters the seed shipped as frozen numbers — completion
    /// was a value that crept up by 0.04 a tap, and the streak beside it was
    /// never read from the log at all. Running this every launch also keeps a
    /// weekly goal honest as the week rolls over.
    private static func settleCircles() {
        let joined = CoreDataStack.shared.fetch(
            CDHabit.self,
            predicate: NSPredicate(format: "isJoined == YES")
        )
        guard !joined.isEmpty else { return }

        for habit in joined {
            HabitService.recomputeState(for: habit)
        }
        CoreDataStack.shared.save()
    }

    // MARK: - Account

    /// Brings the signed-in account's streak and totals up from the log they
    /// were always derivable from but never read.
    private static func settleAccount() {
        guard let me = AppSession.shared.currentUser else { return }
        HabitService.recomputeUserStreak(me)
        CoreDataStack.shared.save()
    }
}
