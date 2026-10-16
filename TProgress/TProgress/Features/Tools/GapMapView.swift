import SwiftUI

// MARK: - The gap map
//
// Missed days, and the returns.
//
// The one page in the app that measures coming back rather than not stopping.
// A streak counts the days you did not miss and says nothing about the days you
// did — whether you returned the following morning or a fortnight later. That
// return is the practice, so the figure at the top of this page is how long it
// usually takes, and there is no other number on it that matters as much.

struct GapMapView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var report = GapService.Report()
    @State private var hasLoaded = false

    private let accent = Color.tpEmber

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "The gap map",
                subtitle: "Days missed, and the way back",
                onBack: { router.pop() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !session.isSignedIn {
                        signedOut
                    } else if !report.hasAnything {
                        empty
                    } else if !report.canRead {
                        tooEarly
                    } else {
                        headline
                        statGrid
                        strip
                        gapList
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

    // MARK: Headline

    private var headline: some View {
        VStack(spacing: 8) {
            Text.tpLabel("Typically away for")

            if let average = report.averageReturn {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(shortFigure(average))
                        .font(TPFont.figure(54, .heavy))
                        .foregroundColor(.tpCream)

                    Text(average == 1 ? "day" : "days")
                        .font(TPFont.display(20, .bold))
                        .foregroundColor(.tpCreamDim)
                }

                Text(returnSentence)
                    .font(TPFont.ui(13))
                    .foregroundColor(.tpCreamDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            } else if report.awayNow > 0 {
                Text("Still away")
                    .font(TPFont.display(30, .heavy))
                    .foregroundColor(.tpCream)

                Text("You are \(report.awayNow) day\(report.awayNow == 1 ? "" : "s") into a gap right now. There is no run to measure until it ends — and it ends whenever you log again.")
                    .font(TPFont.ui(13))
                    .foregroundColor(.tpCreamDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            } else {
                Text("Unbroken")
                    .font(TPFont.display(30, .heavy))
                    .foregroundColor(.tpCream)

                Text("No gaps behind you yet, so there is no returning to measure.")
                    .font(TPFont.ui(13))
                    .foregroundColor(.tpCreamDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(TPGradient.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(accent.opacity(0.24), lineWidth: 1)
        )
        .tpShadow(20, y: 12, opacity: 0.32)
    }

    /// Says exactly what the mean is built from, so one gap is never read as a
    /// trend.
    private var returnSentence: String {
        if report.returns == 1 {
            return "That is one gap so far, so it is a fact rather than a pattern. It will mean more as the log grows."
        }
        return "Across \(report.returns) gaps, that is how long it takes you to come back."
    }

    // MARK: Stats

    private var statGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TPStatTile(
                    value: "\(report.longestAbsence)",
                    caption: "Longest away",
                    color: .tpSky,
                    symbol: "hourglass"
                )
                TPStatTile(
                    value: "\(report.returns)",
                    caption: report.returns == 1 ? "Gap closed" : "Gaps closed",
                    color: .tpMint,
                    symbol: "arrow.uturn.backward"
                )
            }

            HStack(spacing: 10) {
                TPStatTile(
                    value: report.awayNow > 0 ? "\(report.awayNow)" : "—",
                    caption: "Away now",
                    color: report.awayNow > 0 ? .tpSun : .tpMint,
                    symbol: report.awayNow > 0 ? "moon.zzz" : "checkmark"
                )
                TPStatTile(
                    value: "\(report.observedDays)",
                    caption: "Days on record",
                    color: .tpLilac,
                    symbol: "calendar"
                )
            }
        }
    }

    // MARK: Strip

    private var strip: some View {
        TPChartCard(
            label: "The shape of it",
            title: "Days kept, days missed",
            caption: stripCaption
        ) {
            TPHeatmap(
                columns: report.columns,
                weekdayLabels: StatsService.weekdayLabels(),
                monthLabels: StatsService.heatmapMonthLabels(weeks: report.columns.count),
                accent: accent,
                cellSize: 11,
                spacing: 3
            )
        }
    }

    private var stripCaption: String {
        let start = report.firstDay.map { formatted($0) } ?? "the beginning"
        return "Filled days were kept, hollow ones were missed. The record starts on \(start)."
    }

    // MARK: Gaps

    @ViewBuilder
    private var gapList: some View {
        if report.hasGaps {
            VStack(alignment: .leading, spacing: 12) {
                TPSectionHeader(label: "Every gap", title: "What happened after")

                VStack(spacing: 10) {
                    ForEach(report.gaps) { gap in
                        row(gap)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                TPSectionHeader(label: "Every gap", title: "What happened after")
                Text("None. Every day since \(report.firstDay.map { formatted($0) } ?? "the start") is on the record.")
                    .font(TPFont.ui(13))
                    .foregroundColor(.tpCreamFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.tpInkRaised)
                    )
            }
        }
    }

    private func row(_ gap: GapService.Gap) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill((gap.isOpen ? Color.tpSun : accent).opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: gap.isOpen ? "hourglass" : "arrow.uturn.backward")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(gap.isOpen ? .tpSun : accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(gap.length) day\(gap.length == 1 ? "" : "s") away")
                    .font(TPFont.ui(14, .semibold))
                    .foregroundColor(.tpCream)

                Text(range(gap))
                    .font(TPFont.ui(12))
                    .foregroundColor(.tpCreamFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            if gap.isOpen {
                TPTag(text: "Open", color: .tpSun)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
    }

    private func range(_ gap: GapService.Gap) -> String {
        let from = formatted(gap.missedFrom)
        guard let returned = gap.returnedOn else {
            return "Missed from \(from). Still going."
        }
        return "Missed from \(from). Back on \(formatted(returned))."
    }

    // MARK: Empty

    private var signedOut: some View {
        TPEmptyState(
            symbol: "square.grid.3x3",
            title: "Sign in to see this",
            message: "The gap map reads your own log, so it needs one.",
            actionTitle: "Sign in",
            action: { session.presentAuth(prompt: "Sign in to see your gap map.") },
            accent: accent
        )
    }

    private var empty: some View {
        TPEmptyState(
            symbol: "square.grid.3x3",
            title: "Nothing to map yet",
            message: "Log a few days and the shape will appear. The first thing it can show you is where the record starts.",
            actionTitle: "Log something",
            action: { router.push(.compose) },
            accent: accent
        )
    }

    private var tooEarly: some View {
        TPEmptyState(
            symbol: "square.grid.3x3",
            title: "Not enough history yet",
            message: "A gap needs a day before it and a day after it. Your record covers \(report.observedDays) day\(report.observedDays == 1 ? "" : "s") so far.",
            accent: accent
        )
    }

    // MARK: Data

    private func reload() {
        guard session.isSignedIn else {
            report = GapService.Report()
            return
        }
        withAnimation(TPMotion.gentle) {
            report = GapService.report()
        }
    }

    // MARK: Formatting

    private func shortFigure(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
