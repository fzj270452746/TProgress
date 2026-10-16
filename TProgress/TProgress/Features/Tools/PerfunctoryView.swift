import SwiftUI

// MARK: - The one-tap days
//
// How the log was written, not how much of it there is.
//
// The tone of this page is the feature. One tap is the honest shape of a bad
// day, and someone who taps on a day when nothing else was going to happen is
// doing the exact thing this app exists for. So the page counts and describes,
// and never once says whether the number is high or low — because there is no
// version of that sentence that is not a scoreboard.

struct PerfunctoryView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var report = PerfunctoryService.Report()
    @State private var hasLoaded = false

    private let accent = Color.tpBloom

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "The one-tap days",
                subtitle: "This page counts. It does not judge.",
                onBack: { router.pop() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !session.isSignedIn {
                        signedOut
                    } else if !report.hasAnything {
                        empty
                    } else {
                        headline
                        weekdays
                        bands
                        note
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
        VStack(spacing: 10) {
            Text.tpLabel("Logged with one tap")

            Text("\(Int((report.rate * 100).rounded()))%")
                .font(TPFont.figure(54, .heavy))
                .foregroundColor(.tpCream)

            Text("\(report.quick) of your \(report.total) ordinary logs were the kind with nothing written under them.")
                .font(TPFont.ui(13.5))
                .foregroundColor(.tpCreamDim)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)
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

    // MARK: Weekdays

    private var weekdays: some View {
        TPChartCard(
            label: "By day",
            title: "When the tap happens",
            caption: "The share of each weekday's logs that were the one-tap kind."
        ) {
            VStack(spacing: 9) {
                ForEach(report.byWeekday) { bucket in
                    HStack(spacing: 10) {
                        Text(bucket.label)
                            .font(TPFont.ui(12, .semibold))
                            .foregroundColor(.tpCreamDim)
                            .frame(width: 16, alignment: .leading)

                        TPMeter(progress: bucket.rate, height: 7, color: accent)

                        Text(bucket.total > 0 ? "\(Int((bucket.rate * 100).rounded()))%" : "—")
                            .font(TPFont.figure(11.5, .bold))
                            .foregroundColor(.tpCreamFaint)
                            .frame(width: 34, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: Bands

    @ViewBuilder
    private var bands: some View {
        if report.hasTimedSample {
            TPChartCard(
                label: "By hour",
                title: "When you actually log",
                caption: "Drawn from the \(report.timedSample) log\(report.timedSample == 1 ? "" : "s") written in this app, which are the only ones carrying a real clock time."
            ) {
                TPBarChart(
                    values: report.byBand.map { Double($0.total) },
                    labels: report.byBand.map(\.label),
                    colors: [accent]
                )
                .frame(height: 168)
            }
        } else {
            TPChartCard(
                label: "By hour",
                title: "Not yet readable",
                caption: nil
            ) {
                Text("Time of day appears once you have logged a few days in the app rather than in the sample data. The days that came with the app have no real clock time on them, so counting their hours would be inventing something.")
                    .font(TPFont.ui(12.5))
                    .foregroundColor(.tpCreamDim)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Note

    private var note: some View {
        Text("The tap is the practice. A boring log is an honest one — a day you had nothing to say about is still a day you showed up for.")
            .font(TPFont.ui(12.5))
            .foregroundColor(.tpCreamFaint)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }

    // MARK: Empty

    private var signedOut: some View {
        TPEmptyState(
            symbol: "hand.tap",
            title: "Sign in to see this",
            message: "This counts your own log, so it needs one.",
            actionTitle: "Sign in",
            action: { session.presentAuth(prompt: "Sign in to see how you log.") },
            accent: accent
        )
    }

    private var empty: some View {
        TPEmptyState(
            symbol: "hand.tap",
            title: "Nothing to count yet",
            message: "Log a few days and this will show how they were written.",
            actionTitle: "Log something",
            action: { router.push(.compose) },
            accent: accent
        )
    }

    // MARK: Data

    private func reload() {
        guard session.isSignedIn else {
            report = PerfunctoryService.Report()
            return
        }
        withAnimation(TPMotion.gentle) {
            report = PerfunctoryService.report()
        }
    }
}
