import SwiftUI
import CoreData

// MARK: - On this day
//
// What was written on this day a year, a month and a week ago.
//
// Only the lookbacks with something behind them are shown, and when one is
// missing the page says where the record actually starts rather than printing an
// empty card. Early on that means the week alone — which is the honest answer,
// and reading it is part of understanding what the log is.

struct OnThisDayView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var report = MemoryService.Report()
    @State private var hasLoaded = false

    private let accent = Color.tpSun

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "On this day",
                subtitle: subtitle,
                onBack: { router.pop() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !session.isSignedIn {
                        signedOut
                    } else if !report.hasAnything {
                        empty
                    } else {
                        ForEach(report.echoes) { echo in
                            card(echo)
                        }
                        boundary
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

    private var subtitle: String {
        guard let earliest = report.earliestDay else { return "The record so far" }
        return "Your log starts \(formatted(earliest))"
    }

    // MARK: Cards

    private func card(_ echo: MemoryService.Echo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text.tpLabel(echo.label)
                    Text(formatted(echo.date))
                        .font(TPFont.ui(12))
                        .foregroundColor(.tpCreamFaint)
                }

                Spacer(minLength: 8)

                Text("\(echo.entries.count)")
                    .font(TPFont.figure(20, .heavy))
                    .foregroundColor(.tpCream)
            }

            VStack(spacing: 8) {
                ForEach(echo.entries, id: \.objectID) { entry in
                    CheckInRow(entry: entry, accent: entry.habit?.accent ?? accent)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
    }

    // MARK: Boundary
    //
    // Says where the record starts and what is therefore not here yet. Without
    // this the page looks broken; with it, the missing lookbacks are information.

    private var boundary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text.tpLabel("How far back this goes")

            Text(boundaryText)
                .font(TPFont.ui(12.5))
                .foregroundColor(.tpCreamDim)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
    }

    private var boundaryText: String {
        let span = report.spanDays
        let days = "\(span) day\(span == 1 ? "" : "s")"
        guard let earliest = report.earliestDay else {
            return "Nothing has been logged yet."
        }

        let missing = ["1y", "1mo", "1w"].filter { id in
            !report.echoes.contains { $0.id == id }
        }

        guard !missing.isEmpty else {
            return "All three lookbacks have something behind them."
        }

        let names = missing.map { id -> String in
            switch id {
            case "1y": return "a year ago"
            case "1mo": return "a month ago"
            default: return "a week ago"
            }
        }

        let list = ListFormatter.localizedString(byJoining: names)
        return "The record reaches back \(days), to \(formatted(earliest)). There is nothing for \(list) yet — this page fills in as the log ages."
    }

    // MARK: Empty

    private var signedOut: some View {
        TPEmptyState(
            symbol: "calendar.badge.clock",
            title: "Sign in to see this",
            message: "This reads your own log back to you, so it needs one.",
            actionTitle: "Sign in",
            action: { session.presentAuth(prompt: "Sign in to look back.") },
            accent: accent
        )
    }

    private var empty: some View {
        TPEmptyState(
            symbol: "calendar.badge.clock",
            title: "Nothing from before",
            message: "This page fills in as the log ages. A week from now, today will be here.",
            actionTitle: "Log something",
            action: { router.push(.compose) },
            accent: accent
        )
    }

    // MARK: Data

    private func reload() {
        guard session.isSignedIn else {
            report = MemoryService.Report()
            return
        }
        withAnimation(TPMotion.gentle) {
            report = MemoryService.report()
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date)
    }
}
