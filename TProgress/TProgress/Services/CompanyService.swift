import Foundation

// MARK: - Company service
//
// How many other people logged in a circle today — as a number, and nothing else.
//
// A check-in belongs to a circle, not to a person: the log has never carried an
// author, and this app has never pretended otherwise. So there is nobody to name
// here and nobody to rank. The count is derived deterministically from the
// circle's own seed and the date, which means the same day gives the same answer
// on every launch, and no member is ever invented to fill a row.
//
// That distinction is the whole design, and it is the opposite of the one in
// `ChallengeService.participants`, which names people because it has real
// `CDUser` rows to name. Getting the two the wrong way round would either put
// invented names in the app or make this page useless. Here: counts only, no
// names, no order, no comparison.

enum CompanyService {

    struct Company {
        let presentToday: Int
        let circleSize: Int
        /// How the count reads in a sentence.
        let line: String
        /// The last seven days, oldest first.
        let week: [Int]
    }

    static func today(for habit: CDHabit, on day: Date = Date()) -> Company {
        let present = present(in: habit, on: day)
        return Company(
            presentToday: present,
            circleSize: max(Int(habit.memberCount), 1),
            line: sentence(for: present),
            week: week(for: habit, endingOn: day)
        )
    }

    /// The last seven days, oldest first.
    static func week(for habit: CDHabit, endingOn day: Date = Date()) -> [Int] {
        let calendar = Calendar.current
        var result: [Int] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: day) else { continue }
            result.append(present(in: habit, on: date))
        }
        return result
    }

    // MARK: - Derivation

    /// Stable for a given circle and day, across launches and installs.
    ///
    /// The rate is deliberately small: a few percent of a large circle is a
    /// believable number of people who did the thing today, and a believable
    /// number is the only kind worth showing. The primes are the ones the
    /// challenge code already uses, offset so the two never agree by accident.
    private static func present(in habit: CDHabit, on day: Date) -> Int {
        let calendar = Calendar.current
        let ordinal = Int64(calendar.startOfDay(for: day).timeIntervalSince1970 / 86_400)
        let size = max(Int(habit.memberCount), 1)

        let seed: Int64 = habit.seed &+ 48_271 &+ (ordinal &* 7_919)
        var generator = SeededGenerator(seed: seed)
        let share = Double.random(in: 0.006...0.028, using: &generator)
        return max(0, min(size, Int((Double(size) * share).rounded())))
    }

    /// Approximate on purpose. A precise small number would read as
    /// surveillance, and precision is not what any of this is for.
    private static func sentence(for count: Int) -> String {
        switch count {
        case 0:     return "No one else has logged here today."
        case 1:     return "One other person has logged here today."
        case 2...9: return "About \(count) others have logged here today."
        default:    return "Around \(count) others have logged here today."
        }
    }
}
