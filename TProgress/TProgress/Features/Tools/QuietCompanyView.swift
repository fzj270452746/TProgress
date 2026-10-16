import SwiftUI

// MARK: - Quiet company
//
// How many other people logged in each of your circles today — as a number, and
// nothing else.
//
// A check-in belongs to a circle, not to a person. The log has never carried an
// author, this app has never pretended otherwise, and the counts here are
// derived from each circle's own seed so the same day reads the same on every
// launch. Nobody is named, nobody is ordered, and there is nothing to compare.
//
// That is the whole point, and the page says so out loud rather than leaving the
// reader to guess whether a ranking is hiding behind the numbers.

struct QuietCompanyView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var rows: [Row] = []
    @State private var hasLoaded = false

    private let accent = Color.tpSky

    private struct Row: Identifiable {
        let habit: CDHabit
        let company: CompanyService.Company
        var id: UUID { habit.id ?? UUID() }
    }

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "Quiet company",
                subtitle: "Who else was here, without the who",
                onBack: { router.pop() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !session.isSignedIn {
                        signedOut
                    } else if rows.isEmpty {
                        empty
                    } else {
                        intro

                        VStack(spacing: 12) {
                            ForEach(rows) { row in
                                card(row)
                            }
                        }

                        footer
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

    // MARK: Intro

    private var intro: some View {
        Text("A check-in belongs to a circle, not to a person. So these are counts and never names — nobody is ranked here, and there is nothing on this page to be behind on.")
            .font(TPFont.ui(13))
            .foregroundColor(.tpCreamDim)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.tpInkRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(accent.opacity(0.24), lineWidth: 1)
            )
    }

    // MARK: Card

    private func card(_ row: Row) -> some View {
        let company = row.company

        return Button {
            if let id = row.habit.id { router.push(.circle(id)) }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 11) {
                    ZStack {
                        Circle()
                            .fill(row.habit.accent.opacity(0.15))
                            .frame(width: 38, height: 38)

                        TPIcon(
                            name: row.habit.iconAssetName,
                            fallbackSymbol: row.habit.symbol,
                            size: 16,
                            tint: row.habit.accent
                        )
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.habit.title)
                            .font(TPFont.ui(14.5, .semibold))
                            .foregroundColor(.tpCream)
                            .lineLimit(1)

                        Text("\(formatted(company.circleSize)) in the circle")
                            .font(TPFont.ui(11.5))
                            .foregroundColor(.tpCreamFaint)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.tpCreamFaint)
                }

                Text(company.line)
                    .font(TPFont.ui(13))
                    .foregroundColor(.tpCreamDim)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                VStack(alignment: .leading, spacing: 7) {
                    Text.tpLabel("Last seven days", size: 9, tracking: 1.2)

                    TPMeter(
                        progress: weekProgress(company.week),
                        height: 8,
                        color: row.habit.accent
                    )
                }
            }
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.tpInkRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.tpLine, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// The week as a single bar, scaled against the circle's own busiest day
    /// rather than against a target. There is no threshold to fall short of.
    private func weekProgress(_ week: [Int]) -> Double {
        guard let peak = week.max(), peak > 0 else { return 0 }
        let total = week.reduce(0, +)
        return min(1, Double(total) / Double(peak * week.count))
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nobody is named here. There is nothing to compare.")
                .font(TPFont.ui(12.5, .semibold))
                .foregroundColor(.tpCreamDim)

            Text("Counts are derived from each circle's own seed, so the same day reads the same every time you open this. They are approximate on purpose.")
                .font(TPFont.ui(11.5))
                .foregroundColor(.tpCreamFaint)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Empty

    private var signedOut: some View {
        TPEmptyState(
            symbol: "person.3",
            title: "Sign in to see this",
            message: "Company is counted across the circles you have joined.",
            actionTitle: "Sign in",
            action: { session.presentAuth(prompt: "Sign in to see who else is here.") },
            accent: accent
        )
    }

    private var empty: some View {
        TPEmptyState(
            symbol: "person.3",
            title: "No circles yet",
            message: "Join a circle and this will show how many others are keeping it alongside you.",
            actionTitle: "Browse circles",
            action: { router.select(.circles) },
            accent: accent
        )
    }

    // MARK: Data

    private func reload() {
        guard session.isSignedIn else {
            rows = []
            return
        }

        let joined = StatsService.joinedCircles()
        let built = joined.map { Row(habit: $0, company: CompanyService.today(for: $0)) }

        withAnimation(TPMotion.gentle) {
            rows = built
        }
    }

    private func formatted(_ value: Int) -> String {
        value >= 1000 ? String(format: "%.1fk", Double(value) / 1000) : "\(value)"
    }
}
