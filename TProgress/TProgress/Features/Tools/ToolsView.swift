import SwiftUI

// MARK: - Tools
//
// One page holding the instruments a streak cannot show: the days you came back,
// the days you rested, and the shape of what you wrote.
//
// The page explains itself on purpose. A column of statistics under a heading
// called Tools reads like a dashboard, and a dashboard is the one thing this app
// is built not to be — so the first thing on it says what none of the rest does.

struct ToolsView: View {

    @ObservedObject private var router = Router.shared

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "Tools",
                subtitle: "Small instruments",
                onBack: { router.pop() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    intro
                    keeping
                    reading
                    circles
                }
                .padding(.horizontal, TPMetric.gutter)
                .padding(.bottom, 50)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                TPBackdropView(style: .deep)
                TPHalo(color: .tpMint, spread: 1.05)
                    .offset(y: -220)
                TPGrain(opacity: 0.04)
            }
            .ignoresSafeArea()
        )
    }

    // MARK: Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing here scores you.")
                .font(TPFont.display(19, .bold))
                .foregroundColor(.tpCream)

            Text("""
            These are the parts of the log a streak cannot show: the days you came \
            back, the days you rested, and the shape of what you wrote. None of it \
            leaves the device.
            """)
            .font(TPFont.ui(13))
            .foregroundColor(.tpCreamDim)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.tpMint.opacity(0.24), lineWidth: 1)
        )
    }

    // MARK: Keeping

    private var keeping: some View {
        group(
            label: "Keeping the record",
            title: "Before the day",
            rows: [
                Row(symbol: "arrow.down.circle", title: "Minimums",
                    detail: "What still counts",
                    accent: .tpMint, route: .minimums),
                Row(symbol: "moon.zzz", title: "Planned rest",
                    detail: "Never declared after",
                    accent: .tpSky, route: .plannedRest),
                Row(symbol: "clock.arrow.circlepath", title: "Fill in a day",
                    detail: "Up to three days back",
                    accent: .tpSun, route: .backfill),
                Row(symbol: "questionmark.bubble", title: "Questions",
                    detail: "This week's, and yours",
                    accent: .tpLilac, route: .prompts),
            ]
        )
    }

    // MARK: Reading

    private var reading: some View {
        group(
            label: "Reading it back",
            title: "What the log says",
            rows: [
                Row(symbol: "square.grid.3x3", title: "The gap map",
                    detail: "Missed days, and returns",
                    accent: .tpEmber, route: .gapMap),
                Row(symbol: "hand.tap", title: "One-tap days",
                    detail: "How you log, not how much",
                    accent: .tpSun, route: .perfunctory),
                Row(symbol: "textformat.abc", title: "Words & hours",
                    detail: "Notes, and your clock",
                    accent: .tpLilac, route: .wordTime),
                Row(symbol: "calendar.badge.clock", title: "On this day",
                    detail: "A year, month, week ago",
                    accent: .tpMint, route: .onThisDay),
            ]
        )
    }

    // MARK: Circles

    private var circles: some View {
        group(
            label: "Across your circles",
            title: "With other people",
            rows: [
                Row(symbol: "person.3", title: "Quiet company",
                    detail: "Others here, unnamed",
                    accent: .tpSky, route: .quietCompany),
                Row(symbol: "flag", title: "Start lines",
                    detail: "Who began when",
                    accent: .tpBloom, route: .startLine),
            ]
        )
    }

    // MARK: Group

    private struct Row {
        let symbol: String
        let title: String
        let detail: String
        let accent: Color
        let route: TPRoute
    }

    private func group(label: String, title: String, rows: [Row]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TPSectionHeader(label: label, title: title)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.title) { index, row in
                    if index > 0 { TPFadeRule() }

                    TPRow(
                        symbol: row.symbol,
                        title: row.title,
                        detail: row.detail,
                        accent: row.accent
                    ) {
                        router.push(row.route)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.tpInkRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.tpLine, lineWidth: 1)
            )
        }
    }
}
