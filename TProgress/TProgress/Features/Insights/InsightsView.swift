import SwiftUI

// MARK: - Insights
//
// The account's own record, read back. Everything here is derived from the log
// on the way in — nothing on this page is decorative, which is the whole point:
// the app used to draw a trend from a random generator seeded by a row.

struct InsightsView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var snapshot = StatsService.Snapshot()
    @State private var hasLoaded = false

    private let heatmapWeeks = 26

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "Your practice",
                subtitle: subtitle,
                onBack: { router.pop() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headline
                    statGrid
                    heatmapCard
                    monthsCard
                    shareCard
                    reviewEntry
                }
                .padding(.horizontal, TPMetric.gutter)
                .padding(.bottom, 50)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                TPBackdropView(style: .deep)
                TPHalo(color: .tpEmber, spread: 1.05).offset(y: -220)
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

    private var subtitle: String {
        guard session.isSignedIn else { return "Sign in to keep a record" }
        return "\(snapshot.activeDays) day\(snapshot.activeDays == 1 ? "" : "s") on the log"
    }

    // MARK: Headline

    private var headline: some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                TPRing(
                    progress: snapshot.completionRate,
                    size: 96,
                    lineWidth: 10,
                    colors: [.tpEmber, .tpSun]
                )

                VStack(spacing: 0) {
                    Text("\(Int((snapshot.completionRate * 100).rounded()))")
                        .font(TPFont.figure(26, .heavy))
                        .foregroundColor(.tpCream)

                    Text.tpLabel("of goal", size: 8, tracking: 1)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Last 30 days")
                    .font(TPFont.display(20, .bold))
                    .foregroundColor(.tpCream)

                Text("Measured against what your circles' goals actually ask for, not against every day on the calendar.")
                    .font(TPFont.ui(12))
                    .foregroundColor(.tpCreamFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(TPGradient.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.tpEmber.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: Numbers

    private var statGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TPStatTile(
                    value: "\(snapshot.currentStreak)",
                    caption: "Current streak",
                    color: .tpSun,
                    symbol: "flame.fill"
                )
                TPStatTile(
                    value: "\(snapshot.longestStreak)",
                    caption: "Longest",
                    color: .tpLilac,
                    symbol: "trophy.fill"
                )
            }

            HStack(spacing: 10) {
                TPStatTile(
                    value: "\(snapshot.sessions)",
                    caption: "Sessions",
                    color: .tpMint,
                    symbol: "checkmark.circle.fill"
                )
                TPStatTile(
                    value: hoursLabel,
                    caption: "Time on it",
                    color: .tpSky,
                    symbol: "clock.fill"
                )
            }
        }
    }

    private var hoursLabel: String {
        let minutes = snapshot.minutes
        guard minutes > 0 else { return "0m" }
        return minutes >= 60
            ? String(format: "%.1fh", Double(minutes) / 60)
            : "\(minutes)m"
    }

    // MARK: Heatmap

    private var heatmapCard: some View {
        TPChartCard(
            label: "Showing up",
            title: "Half a year, one cell a day",
            caption: "Deeper means more circles logged that day. Empty cells are days the log stayed empty."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                TPHeatmap(
                    columns: snapshot.heatmap,
                    weekdayLabels: StatsService.weekdayLabels(),
                    monthLabels: StatsService.heatmapMonthLabels(weeks: heatmapWeeks),
                    accent: .tpEmber,
                    cellSize: 10
                )

                TPHeatmapLegend(accent: .tpEmber)
            }
        }
    }

    // MARK: Months

    @ViewBuilder
    private var monthsCard: some View {
        if snapshot.monthValues.contains(where: { $0 > 0 }) {
            TPChartCard(
                label: "Rhythm",
                title: "Sessions by month",
                caption: "Every check-in in every circle you are in."
            ) {
                TPBarChart(
                    values: snapshot.monthValues,
                    labels: snapshot.monthLabels,
                    colors: [.tpMint]
                )
                .frame(height: 168)
            }
        } else {
            TPChartCard(
                label: "Rhythm",
                title: "Sessions by month",
                caption: "Nothing logged in the last six months."
            ) {
                TPEmptyState(
                    symbol: "chart.bar",
                    title: "No months to compare",
                    message: "Log a session and this fills in.",
                    accent: .tpMint
                )
            }
        }
    }

    // MARK: Share

    @ViewBuilder
    private var shareCard: some View {
        if snapshot.share.count > 1 {
            TPChartCard(
                label: "Where it goes",
                title: "Share of the log",
                caption: "Which circles the time actually went to."
            ) {
                HStack(alignment: .center, spacing: 18) {
                    TPDonutChart(
                        slices: snapshot.share.map {
                            .init(label: $0.title, value: Double($0.count), color: .tpAccent($0.accentIndex))
                        }
                    )
                    .frame(width: 132, height: 132)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(snapshot.share.enumerated()), id: \.offset) { _, slice in
                            legendRow(slice)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func legendRow(_ slice: StatsService.CircleTotal) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color.tpAccent(slice.accentIndex))
                .frame(width: 8, height: 8)

            Text(slice.title)
                .font(TPFont.ui(12))
                .foregroundColor(.tpCreamDim)
                .lineLimit(1)

            Spacer(minLength: 6)

            Text("\(slice.count)")
                .font(TPFont.figure(12, .bold))
                .foregroundColor(.tpCream)
        }
    }

    // MARK: Year review

    private var reviewEntry: some View {
        Button {
            TPHaptic.tap()
            router.push(.yearReview)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(TPGradient.accent(.tpLilac))
                        .frame(width: 44, height: 44)

                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.tpInk.opacity(0.82))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Your \(currentYear) in review")
                        .font(TPFont.display(17, .bold))
                        .foregroundColor(.tpCream)

                    Text("The year, one card at a time.")
                        .font(TPFont.ui(12))
                        .foregroundColor(.tpCreamFaint)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.tpCreamFaint)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.tpLilac.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.tpLilac.opacity(0.26), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    // MARK: Data

    private func reload() {
        guard session.isSignedIn else {
            snapshot = StatsService.Snapshot()
            return
        }
        snapshot = StatsService.snapshot(heatmapWeeks: heatmapWeeks)
    }
}
