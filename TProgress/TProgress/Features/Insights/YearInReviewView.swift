import SwiftUI

// MARK: - Year in review
//
// The one place in the app that is allowed to be loud. A paged run through the
// year: what was logged, how long it took, the longest unbroken run, the month
// that carried the most, and the whole year as a grid.
//
// Paging is a `TabView` in page style because `NavigationStack` does not exist
// on iOS 15 and the app routes everything by hand.

struct YearInReviewView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared

    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var totals = StatsService.YearTotals()
    @State private var snapshot = StatsService.Snapshot()
    @State private var page = 0

    private var pages: [ReviewPage] { ReviewPage.allCases }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar

                TabView(selection: $page) {
                    ForEach(pages, id: \.rawValue) { item in
                        content(for: item)
                            .tag(item.rawValue)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(TPMotion.gentle, value: page)

                bottomBar
            }
        }
        .onAppear(perform: reload)
    }

    // MARK: Chrome

    private var background: some View {
        ZStack {
            TPBackdropView(style: .deep)
            TPHalo(color: .tpLilac, spread: 1.15).offset(y: -180)
            TPGrain(opacity: 0.05)
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    router.pop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.tpCream)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.tpGlass))
                }
                .buttonStyle(.plain)

                progressBar

                Text("\(page + 1)/\(pages.count)")
                    .font(TPFont.figure(11, .bold))
                    .foregroundColor(.tpCreamFaint)
                    .frame(width: 32)
            }
            .padding(.horizontal, TPMetric.gutter)
            .padding(.top, 12)
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.tpInkWell)

                Capsule()
                    .fill(TPGradient.ember)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 4)
        .animation(TPMotion.gentle, value: page)
    }

    private var fraction: CGFloat {
        pages.isEmpty ? 0 : CGFloat(page + 1) / CGFloat(pages.count)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            TPQuietButton(title: page == 0 ? "Skip" : "Back", size: 13) {
                if page == 0 {
                    router.pop()
                } else {
                    withAnimation(TPMotion.gentle) { page -= 1 }
                }
            }

            Spacer(minLength: 0)

            if page == pages.count - 1 {
                TPOutlineButton(title: "Copy summary", symbol: "doc.on.doc", fullWidth: false) {
                    copySummary()
                }
            } else {
                TPQuietButton(title: "Next", size: 13) {
                    withAnimation(TPMotion.gentle) { page += 1 }
                }
            }
        }
        .padding(.horizontal, TPMetric.gutter)
        .padding(.bottom, 26)
        .padding(.top, 10)
    }

    // MARK: Pages

    @ViewBuilder
    private func content(for item: ReviewPage) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            switch item {
            case .cover:
                cover
            case .sessions:
                figure(
                    value: "\(totals.sessions)",
                    unit: "sessions",
                    title: "Time you actually put in",
                    caption: totals.hasAnything
                        ? "Every check-in across every circle, counted."
                        : "Nothing logged this year yet."
                )
            case .time:
                figure(
                    value: hoursValue,
                    unit: hoursUnit,
                    title: "Measured, not estimated",
                    caption: "Straight off the timer and the detail you typed in."
                )
            case .streak:
                figure(
                    value: "\(totals.longestStreak)",
                    unit: totals.longestStreak == 1 ? "day" : "days",
                    title: "Your longest unbroken run",
                    caption: "The best stretch of consecutive days with something logged."
                )
            case .bestMonth:
                figure(
                    value: totals.bestMonth ?? "—",
                    unit: "",
                    title: "The month that carried the most",
                    caption: totals.bestMonth == nil
                        ? "No month stands out yet."
                        : "Where the effort piled up highest this year."
                )
            case .topCircle:
                figure(
                    value: totals.topCircle ?? "—",
                    unit: "",
                    title: "Where most of it went",
                    caption: "The circle that took the largest share of your attention.",
                    compactValue: true
                )
            case .grid:
                gridPage
            case .closing:
                closing
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, TPMetric.gutter)
        .frame(maxWidth: .infinity)
    }

    private var cover: some View {
        VStack(spacing: 14) {
            Text.tpLabel("In review", size: 11, tracking: 3, color: .tpLilac)

            Text("\(year)")
                .font(TPFont.display(72, .heavy))
                .foregroundColor(.tpCream)

            Text(totals.activeDays == 0
                 ? "A quiet year. Nothing on the log yet."
                 : "\(totals.activeDays) day\(totals.activeDays == 1 ? "" : "s") you showed up.")
                .font(TPFont.ui(14))
                .foregroundColor(.tpCreamDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
        }
    }

    private func figure(
        value: String,
        unit: String,
        title: String,
        caption: String,
        compactValue: Bool = false
    ) -> some View {
        VStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(value)
                    .font(compactValue ? TPFont.display(34, .heavy) : TPFont.figure(64, .heavy))
                    .foregroundColor(.tpCream)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)

                if !unit.isEmpty {
                    Text.tpLabel(unit, size: 11, tracking: 2.4, color: .tpSun)
                }
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(TPFont.display(19, .bold))
                    .foregroundColor(.tpCream)
                    .multilineTextAlignment(.center)

                Text(caption)
                    .font(TPFont.ui(13))
                    .foregroundColor(.tpCreamFaint)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 18)
            }
        }
    }

    private var gridPage: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("The whole year")
                    .font(TPFont.display(22, .bold))
                    .foregroundColor(.tpCream)

                Text("One cell a day. Deeper means more circles logged.")
                    .font(TPFont.ui(12.5))
                    .foregroundColor(.tpCreamFaint)
                    .multilineTextAlignment(.center)
            }

            TPHeatmap(
                columns: snapshot.heatmap,
                weekdayLabels: StatsService.weekdayLabels(),
                monthLabels: StatsService.heatmapMonthLabels(weeks: snapshot.heatmapWeeks),
                accent: .tpLilac,
                cellSize: 5.5,
                spacing: 1
            )

            TPHeatmapLegend(accent: .tpLilac, cellSize: 9)
        }
    }

    private var closing: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(TPGradient.accent(.tpSun))
                    .frame(width: 108, height: 108)
                    .tpEmberGlow(.tpSun, strength: 0.6)

                Image(systemName: "flame.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.tpInk.opacity(0.82))
            }

            VStack(spacing: 8) {
                Text("\(snapshot.currentStreak) day streak, running")
                    .font(TPFont.display(21, .bold))
                    .foregroundColor(.tpCream)

                Text("The year is only interesting because the log is honest. Keep it that way.")
                    .font(TPFont.ui(13))
                    .foregroundColor(.tpCreamDim)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 22)
            }
        }
    }

    // MARK: Data

    private var hoursValue: String {
        guard totals.minutes > 0 else { return "0" }
        return String(format: "%.1f", Double(totals.minutes) / 60)
    }

    private var hoursUnit: String { totals.minutes > 0 ? "hours" : "logged" }

    private func reload() {
        guard session.isSignedIn else {
            totals = StatsService.YearTotals()
            snapshot = StatsService.Snapshot()
            return
        }
        totals = StatsService.yearTotals(year)
        snapshot = StatsService.snapshot(heatmapWeeks: 53)
    }

    private func copySummary() {
        let lines = [
            "My \(year) in TProgress",
            "\(totals.sessions) sessions across \(totals.activeDays) days",
            totals.minutes > 0 ? "\(hoursValue) hours logged" : nil,
            "Longest streak: \(totals.longestStreak) days",
            totals.bestMonth.map { "Biggest month: \($0)" },
            totals.topCircle.map { "Most of it went to \($0)" }
        ].compactMap { $0 }

        UIPasteboard.general.string = lines.joined(separator: "\n")
        tpToast("Summary copied", tone: .success, symbol: "doc.on.doc")
    }
}

// MARK: - Pages

private enum ReviewPage: Int, CaseIterable {
    case cover
    case sessions
    case time
    case streak
    case bestMonth
    case topCircle
    case grid
    case closing
}
