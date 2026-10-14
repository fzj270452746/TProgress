import SwiftUI
import CoreData

// MARK: - Recap detail
//
// A circle's stage summary, charted. Three periods are kept per circle and
// rebuilt from the log on every launch, so what is drawn here is the account's
// actual practice over the last 30 days, six weeks and quarter — not a shape
// invented from a seed.

struct RecapDetailView: View {

    let habit: CDHabit

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared

    @State private var kind: RecapKind = .thirtyDay
    @State private var summaries: [RecapKind: CDStageSummary] = [:]
    @State private var isPublishing = false

    @Namespace private var segment

    private var accent: Color { habit.accent }
    private var summary: CDStageSummary? { summaries[kind] }

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "Recap",
                subtitle: habit.title,
                onBack: { router.pop() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !summaries.isEmpty {
                        periodPicker

                        if let summary {
                            hero(summary)
                            trendCard(summary)
                            consistencyCard(summary)
                            volumeCard(summary)
                            reflectionCard(summary)
                            publishButton(summary)
                        }
                    } else {
                        TPEmptyState(
                            symbol: "chart.xyaxis.line",
                            title: "No recap yet",
                            message: "Join this circle and log a few days — the recaps build themselves from your log.",
                            accent: accent
                        )
                    }
                }
                .padding(.horizontal, TPMetric.gutter)
                .padding(.bottom, 50)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                // A pushed page covers the tab root, so it paints its own ground. Kept
                // deeper than a tab's so forms and long reads stay comfortable.
                TPBackdropView(style: .deep)
                TPHalo(color: accent, spread: 1.05)
                    .offset(y: -230)
                TPGrain(opacity: 0.04)
            }
            .ignoresSafeArea()
        )
        .onAppear(perform: reload)
    }

    // MARK: Period

    private var periodPicker: some View {
        TPSegmented(
            items: availableKinds,
            selection: $kind,
            title: { $0.label },
            namespace: segment
        )
        .padding(.top, 2)
    }

    private var availableKinds: [RecapKind] {
        RecapKind.allCases.filter { summaries[$0] != nil }
    }

    // MARK: Hero

    private func hero(_ summary: CDStageSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(summary.heading)
                .font(TPFont.display(26, .heavy))
                .foregroundColor(.tpCream)
                .fixedSize(horizontal: false, vertical: true)

            Text.tpLabel(summary.periodLabel, size: 10, tracking: 1.6)

            HStack(spacing: 18) {
                ZStack {
                    TPRing(
                        progress: summary.completionRate,
                        size: 92,
                        lineWidth: 9,
                        colors: [accent, accent.opacity(0.45)]
                    )
                    VStack(spacing: 0) {
                        Text("\(Int(summary.completionRate * 100))")
                            .font(TPFont.figure(25, .heavy))
                            .foregroundColor(.tpCream)
                        Text.tpLabel("of goal", size: 8, tracking: 1)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    TPStatTile(
                        value: summary.totalLabel,
                        caption: "Total logged",
                        color: accent,
                        symbol: "sum"
                    )
                    TPStatTile(
                        value: "\(RecapService.sessions(of: summary))",
                        caption: "Sessions",
                        color: .tpMint,
                        symbol: "checkmark.circle"
                    )
                }

                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(TPGradient.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(accent.opacity(0.24), lineWidth: 1)
        )
        .padding(.top, 4)
    }

    // MARK: Trend

    private func trendCard(_ summary: CDStageSummary) -> some View {
        TPChartCard(
            label: "Trend",
            title: "Consistency across the period",
            caption: "Each point is the share of its window's days that carry a log."
        ) {
            TPLineChart(
                values: summary.trendValues,
                labels: summary.trendLabels,
                color: accent
            )
            .frame(height: 168)
        }
    }

    // MARK: Consistency

    private func consistencyCard(_ summary: CDStageSummary) -> some View {
        let logged = RecapService.loggedDays(of: summary)
        let span = RecapService.periodDays(of: summary)
        let missed = max(span - logged, 0)

        return TPChartCard(
            label: "Consistency",
            title: "How the days split",
            caption: "Two numbers only: days with a log, and days without."
        ) {
            if logged == 0 {
                Text("Nothing logged in this window.")
                    .font(TPFont.ui(13))
                    .foregroundColor(.tpCreamFaint)
            } else {
                HStack(spacing: 16) {
                    TPDonutChart(slices: [
                        .init(label: "Logged", value: Double(logged), color: accent),
                        .init(label: "Missed", value: Double(max(missed, 0)), color: .tpBloom)
                    ])
                    .frame(width: 148, height: 148)

                    VStack(alignment: .leading, spacing: 11) {
                        legend(color: accent, title: "Logged", value: "\(logged) d")
                        legend(color: .tpBloom, title: "Missed", value: "\(missed) d")
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func legend(color: Color, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(title)
                .font(TPFont.ui(13, .medium))
                .foregroundColor(.tpCream)

            Spacer(minLength: 4)

            Text(value)
                .font(TPFont.figure(13, .bold))
                .foregroundColor(.tpCreamDim)
        }
        .frame(width: 140)
    }

    // MARK: Volume

    private func volumeCard(_ summary: CDStageSummary) -> some View {
        let values = RecapService.volumeBuckets(of: summary)

        return TPChartCard(
            label: "Volume",
            title: "What each window held",
            caption: values.contains(where: { $0 > 0 })
                ? "Measured in \(summary.unit ?? "units")."
                : "Nothing measured in this window."
        ) {
            TPBarChart(
                values: values,
                labels: summary.trendLabels,
                colors: [accent.opacity(0.9), accent.opacity(0.55)]
            )
            .frame(height: 168)
        }
    }

    // MARK: Reflection

    private func reflectionCard(_ summary: CDStageSummary) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text.tpLabel("Read back")

            HStack(alignment: .top, spacing: 12) {
                Text("\u{201C}")
                    .font(TPFont.display(48, .heavy))
                    .foregroundColor(accent.opacity(0.5))
                    .offset(y: -14)

                Text(summary.reflectionText)
                    .font(TPFont.display(17))
                    .foregroundColor(.tpCream)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(accent.opacity(0.24), lineWidth: 1)
        )
    }

    // MARK: Publish

    private func publishButton(_ summary: CDStageSummary) -> some View {
        VStack(spacing: 8) {
            TPPrimaryButton(
                title: "Publish as a post",
                symbol: "paperplane.fill",
                isLoading: isPublishing,
                isEnabled: summary.totalValue > 0 || summary.completionRate > 0
            ) {
                session.withAuth(prompt: "Sign in to share this recap.") {
                    publish(summary)
                }
            }

            Text("Posts the numbers above to your feed, tagged to \(habit.title).")
                .font(TPFont.ui(11.5))
                .foregroundColor(.tpCreamFaint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Data

    private func reload() {
        // A circle that has never been opened since the upgrade may not have its
        // recaps yet; building them here keeps the page from being empty for
        // someone who came straight to it.
        if RecapService.generated(for: habit).isEmpty {
            RecapService.syncRecaps(for: habit)
            CoreDataStack.shared.save()
        }

        var loaded: [RecapKind: CDStageSummary] = [:]
        for recap in RecapService.generated(for: habit) {
            if let kind = recap.kind { loaded[kind] = recap }
        }
        summaries = loaded

        if loaded[kind] == nil, let first = RecapKind.allCases.first(where: { loaded[$0] != nil }) {
            kind = first
        }
    }

    private func publish(_ summary: CDStageSummary) {
        isPublishing = true
        Task {
            await TPLoadingRun.run(minimumDuration: 0.9, message: "Publishing") {
                if RecapService.publish(summary) != nil {
                    RefreshSignal.shared.bumpFeed()
                }
            }
            isPublishing = false
            TPHaptic.success()
            tpToast("Recap published", tone: .success, symbol: "paperplane.fill")
        }
    }
}
