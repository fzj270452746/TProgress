import Foundation

// MARK: - Prompt service
//
// One question, shared by a circle, for a week.
//
// The hardest part of keeping a log is having something to say, and a shared
// question answers that without putting a scoreboard in the middle: everyone in
// the circle sits with the same sentence for the same seven days, and what each
// of them writes under it is their own.
//
// The pool is hardcoded — no network, no model, no download — and chosen by the
// circle's category, with a general set behind it so no circle is ever left
// without a question. A circle can replace its questions or add to them.

enum PromptService {

    /// The question a circle is sitting with this week.
    ///
    /// Deterministic from the circle's own seed and the week number, so every
    /// member sees the same question at the same time, and it does not change
    /// between launches.
    static func current(for habit: CDHabit, on day: Date = Date()) -> String {
        let questions = pool(for: habit)
        guard !questions.isEmpty else { return "" }

        let calendar = Calendar.current
        let ordinal = Int(calendar.startOfDay(for: day).timeIntervalSince1970 / 86_400)
        let week = ordinal / 7
        let seed = Int(truncatingIfNeeded: habit.seed)

        // The double modulo keeps a negative seed from indexing backwards off
        // the front of the array — the same guard `Color.tpAccent` uses.
        let index = ((week &+ seed) % questions.count + questions.count) % questions.count
        return questions[index]
    }

    /// What this circle can draw on: its own questions, plus or instead of the
    /// built-in ones depending on the mode.
    static func pool(for habit: CDHabit) -> [String] {
        let builtIn = library[habit.categoryLabel] ?? general
        let custom = habit.customPrompts

        guard !custom.isEmpty else { return builtIn }
        return habit.promptReplacesBuiltIns ? custom : custom + builtIn
    }

    /// Whether a circle is on its own questions.
    static func isCustomised(_ habit: CDHabit) -> Bool { habit.hasCustomPrompts }

    static func setCustom(_ habit: CDHabit, prompts: [String], replacesBuiltIns: Bool) {
        habit.promptCustom = prompts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        habit.promptMode = replacesBuiltIns ? "replace" : "extend"
        CoreDataStack.shared.save()
    }

    static func clearCustom(_ habit: CDHabit) {
        habit.promptCustom = ""
        habit.promptMode = "extend"
        CoreDataStack.shared.save()
    }

    // MARK: - Library
    //
    // Written to ask what happened and how it went, never whether it got
    // finished. The second kind of question turns a log into a scoreboard, which
    // is the one thing this app is built not to be.

    private static let general: [String] = [
        "What made today's version harder than yesterday's?",
        "What did you do that nobody will see?",
        "Where did you nearly stop, and what kept you going?",
        "What was the smallest part, and did it count?",
        "What did showing up actually cost you today?",
        "What would the minimum have been — and did you do more?",
        "What did you notice only because you were paying attention?",
        "What made it easy today?",
    ]

    private static let library: [String: [String]] = [

        "Reading": [
            "What did you read that you would have skipped if you were in a hurry?",
            "Which line stopped you?",
            "What did you read twice?",
            "Where did your attention actually go?",
            "What did the page know that you didn't?",
        ],

        "Writing": [
            "What sentence did you keep?",
            "What did you cut, and why?",
            "Where did the writing resist you?",
            "What did you write that surprised you?",
            "Which part was true, and which part was just easy?",
        ],

        "Music": [
            "Which bar is still hard?",
            "What did your hands learn before you did?",
            "Where did you slow down on purpose?",
            "What sounded wrong until it didn't?",
            "What did you play badly and enjoy anyway?",
        ],

        "Movement": [
            "How did the first ten minutes feel against the last ten?",
            "What did you pass that you usually run past?",
            "Where did your body ask you to stop, and what did you do?",
            "What was the weather doing?",
            "Which part hurt, and was it the useful kind?",
        ],

        "Recovery": [
            "What did resting actually give you?",
            "What was hard about stopping?",
            "How did you talk yourself into it?",
            "What did your body say afterwards?",
            "What were you avoiding by doing this?",
        ],

        "Craft": [
            "What did you make that you would throw away — and did you?",
            "Where did the work get boring, and did you stay?",
            "What did you finish badly rather than not at all?",
            "What did the part that failed teach you?",
            "What would you do differently with one more hour?",
        ],

        "Language": [
            "Which word kept slipping?",
            "What did you understand without translating?",
            "Where did you guess, and were you right?",
            "What sounded wrong in your mouth?",
            "What could you say today that you couldn't last month?",
        ],

        "Reflection": [
            "What was true today that you would rather not write down?",
            "What did you notice on the way here?",
            "What are you carrying that you didn't choose?",
            "What went better than you expected?",
            "What would you tell yesterday's version of you?",
        ],
    ]
}
