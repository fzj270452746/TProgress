import Foundation

// MARK: - Word service
//
// What the notes actually say, read locally and kept local.
//
// Nothing here leaves the device and nothing is inferred beyond counting: the
// words are tallied, the hours are tallied, and the two are reported separately
// because they do not rest on the same evidence. A note is a note whenever it
// was written. A clock time only exists on rows written in this app — the sample
// data shipped without one — so the hours come from a smaller set, and the page
// says so rather than presenting both as equally solid.

enum WordService {

    struct Word: Identifiable {
        let id: String
        let text: String
        let count: Int
    }

    struct Band: Identifiable {
        let id: String
        let label: String
        let count: Int
    }

    struct Report {
        var words: [Word] = []
        var totalWords = 0
        var notesRead = 0

        var bands: [Band] = []
        /// How many notes carry a real clock time.
        var timedNotes = 0

        var hasAnything: Bool { totalWords > 0 }
        var hasTimedNotes: Bool { timedNotes > 0 }
    }

    static func report(limit: Int = 28) -> Report {
        report(for: StatsService.joinedCircles(), limit: limit)
    }

    static func report(for circles: [CDHabit], limit: Int = 28) -> Report {
        let calendar = Calendar.current
        let entries = circles
            .flatMap(\.checkIns)
            .filter { $0.isMine && $0.hasNote }

        var report = Report()
        report.notesRead = entries.count

        var counts: [String: Int] = [:]
        for entry in entries {
            for token in tokens(in: entry.noteText) {
                counts[token, default: 0] += 1
            }
        }

        report.totalWords = counts.values.reduce(0, +)

        // Ties are broken alphabetically so the list never reshuffles between
        // launches for a reason the reader cannot see.
        report.words = counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(limit)
            .map { Word(id: $0.key, text: $0.key, count: $0.value) }

        let timed = entries.filter(\.wasWrittenByHand)
        report.timedNotes = timed.count

        var totals = Array(repeating: 0, count: TimeBand.allCases.count)
        for entry in timed {
            guard let stamp = entry.createdAt else { continue }
            guard let band = TimeBand(hour: calendar.component(.hour, from: stamp)) else { continue }
            totals[band.index] += 1
        }
        report.bands = TimeBand.allCases.map {
            Band(id: $0.rawValue, label: $0.shortLabel, count: totals[$0.index])
        }

        return report
    }

    // MARK: - Tokenising

    /// Lowercased words of three letters or more, with the small English
    /// connectives dropped. No dependency and no download: the list is short
    /// enough to write out by hand, and a longer one would change very little.
    private static func tokens(in text: String) -> [String] {
        var result: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords]) { substring, _, _, _ in
            guard let word = substring?.lowercased(), word.count >= 3 else { return }
            // Drops pure numerals once the punctuation is gone.
            guard word.rangeOfCharacter(from: .letters) != nil else { return }
            guard !stopWords.contains(word) else { return }
            result.append(word)
        }
        return result
    }

    private static let stopWords: Set<String> = [
        "the", "and", "for", "was", "were", "with", "that", "this", "but", "not",
        "you", "your", "have", "had", "has", "just", "did", "didn", "then", "than",
        "them", "they", "there", "here", "when", "what", "which", "while", "from",
        "into", "out", "about", "after", "before", "again", "still", "only", "some",
        "more", "most", "much", "very", "been", "being", "are", "its", "got", "get",
        "went", "made", "make", "one", "two", "all", "any", "can", "could", "would",
        "should", "today", "days", "does", "doing", "done", "because", "over", "off",
    ]
}
