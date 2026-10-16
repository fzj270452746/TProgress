import SwiftUI

// MARK: - Words & hours
//
// What the notes say, read locally and kept local.
//
// The two halves rest on different evidence and the page says so rather than
// presenting them as equally solid. A note is a note whenever it was written; a
// clock time only exists on rows written in this app. That disclosure is not a
// disclaimer bolted on at the end — it is the difference between reporting an
// observation and inventing one.

struct WordTimeView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var report = WordService.Report()
    @State private var hasLoaded = false

    private let accent = Color.tpLilac

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "Words & hours",
                subtitle: "Your notes, and your clock",
                onBack: { router.pop() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !session.isSignedIn {
                        signedOut
                    } else if !report.hasAnything {
                        empty
                    } else {
                        statGrid
                        cloud
                        bands
                        disclosure
                    }
                }
                .padding(.horizontal, TPMetric.gutter)
                .padding(.bottom, 50)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                TPBackdropView(style: .deep)
                TPHalo(color: accent, spread: 1.05)
                    .offset(y: -220)
                TPGrain(opacity: 0.04)
            }
            .ignoresSafeArea()
        )
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            reload()
        }
        .onChange(of: refresh.practice) { _ in reload() }
    }

    // MARK: Stats

    private var statGrid: some View {
        HStack(spacing: 10) {
            TPStatTile(
                value: "\(report.totalWords)",
                caption: "Words written",
                color: accent,
                symbol: "textformat.abc"
            )
            TPStatTile(
                value: "\(report.notesRead)",
                caption: report.notesRead == 1 ? "Note" : "Notes",
                color: .tpMint,
                symbol: "text.alignleft"
            )
        }
    }

    // MARK: Cloud

    private var cloud: some View {
        TPChartCard(
            label: "What recurs",
            title: "The words you come back to",
            caption: "Counted from your own notes, on this device. Nothing is sent anywhere."
        ) {
            if report.words.isEmpty {
                Text("The notes you have written are too short to have words in them yet.")
                    .font(TPFont.ui(12.5))
                    .foregroundColor(.tpCreamDim)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 7) {
                            ForEach(row) { word in
                                TPTag(
                                    text: word.text,
                                    color: tierColor(word.count),
                                    filled: word.count >= topCount
                                )
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }

    private var topCount: Int { report.words.first?.count ?? 1 }

    private func tierColor(_ count: Int) -> Color {
        guard topCount > 1 else { return accent }
        let ratio = Double(count) / Double(topCount)
        if ratio > 0.6 { return accent }
        if ratio > 0.3 { return .tpSky }
        return .tpCreamFaint
    }

    /// Greedy line breaking, on a rough character budget rather than measured
    /// text — close enough that the rows read as a cloud rather than a list, and
    /// it costs nothing at layout time.
    private var rows: [[WordService.Word]] {
        var result: [[WordService.Word]] = []
        var current: [WordService.Word] = []
        var width = 0
        let budget = 26

        for word in report.words {
            let cost = word.text.count + 4
            if width + cost > budget, !current.isEmpty {
                result.append(current)
                current = []
                width = 0
            }
            current.append(word)
            width += cost
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    // MARK: Bands

    @ViewBuilder
    private var bands: some View {
        if report.hasTimedNotes {
            TPChartCard(
                label: "Your clock",
                title: "When the lines get written",
                caption: "From the \(report.timedNotes) note\(report.timedNotes == 1 ? "" : "s") with a real time on \(report.timedNotes == 1 ? "it" : "them")."
            ) {
                TPBarChart(
                    values: report.bands.map { Double($0.count) },
                    labels: report.bands.map(\.label),
                    colors: [accent]
                )
                .frame(height: 168)
            }
        }
    }

    // MARK: Disclosure

    private var disclosure: some View {
        Text("Words come from every note you have written. The clock only counts the days you logged by hand in this app — the days that arrived with the sample data carry no real time, so they are counted in the words and left out of the hours.")
            .font(TPFont.ui(11.5))
            .foregroundColor(.tpCreamFaint)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }

    // MARK: Empty

    private var signedOut: some View {
        TPEmptyState(
            symbol: "textformat.abc",
            title: "Sign in to see this",
            message: "This reads your own notes, so it needs a log to read.",
            actionTitle: "Sign in",
            action: { session.presentAuth(prompt: "Sign in to read your notes back.") },
            accent: accent
        )
    }

    private var empty: some View {
        TPEmptyState(
            symbol: "textformat.abc",
            title: "No notes yet",
            message: "Write a line when you log and this page fills in. Even one sentence is enough to start.",
            actionTitle: "Log something",
            action: { router.push(.compose) },
            accent: accent
        )
    }

    // MARK: Data

    private func reload() {
        guard session.isSignedIn else {
            report = WordService.Report()
            return
        }
        withAnimation(TPMotion.gentle) {
            report = WordService.report()
        }
    }
}
