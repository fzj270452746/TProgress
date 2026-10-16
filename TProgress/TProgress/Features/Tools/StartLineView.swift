import SwiftUI

// MARK: - Start lines
//
// When everyone walked in.
//
// A challenge carries a window — a start date and an end date — and that window
// describes the challenge, not the people. What it cannot tell you is the day
// each account actually joined, which is the half that makes a group feel like
// one. That is what this page shows, and it is the one place in the app where
// names are used for something social, because these are real accounts rather
// than check-ins with no author.

struct StartLineView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var lines: [Line] = []
    @State private var hasLoaded = false

    private let accent = Color.tpBloom

    private struct Line: Identifiable {
        let challenge: CDChallenge
        let start: ChallengeService.StartLine
        var id: UUID { challenge.id ?? UUID() }
    }

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "Start lines",
                subtitle: "Who began when",
                onBack: { router.pop() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !session.isSignedIn {
                        signedOut
                    } else if lines.isEmpty {
                        empty
                    } else {
                        intro

                        ForEach(lines) { line in
                            card(line)
                        }
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
        Text("Everyone in a challenge began on the same day. The bar below is the calendar, not the people — it shows when each account arrived, and there is no line to be ahead of.")
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

    private func card(_ line: Line) -> some View {
        let start = line.start
        let challenge = line.challenge

        return VStack(alignment: .leading, spacing: 16) {
            header(challenge, start: start)

            track(start)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    TPStatTile(
                        value: "\(start.onTheLine)",
                        caption: "On the line",
                        color: .tpMint,
                        symbol: "person.3"
                    )
                    TPStatTile(
                        value: "\(start.totalDays)",
                        caption: "Days in all",
                        color: .tpSky,
                        symbol: "calendar"
                    )
                    TPStatTile(
                        value: start.myDayIndex == 0 ? "Start" : "+\(start.myDayIndex)",
                        caption: "You came in",
                        color: accent,
                        symbol: "flag"
                    )
                }
            }

            members(start)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(TPGradient.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
    }

    private func header(_ challenge: CDChallenge, start: ChallengeService.StartLine) -> some View {
        Button {
            if let id = challenge.id { router.push(.challenge(id)) }
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(challenge.accent.opacity(0.15))
                        .frame(width: 38, height: 38)

                    Image(systemName: "flag")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(challenge.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.heading)
                        .font(TPFont.ui(15, .semibold))
                        .foregroundColor(.tpCream)
                        .lineLimit(1)

                    Text("\(challenge.kind.label) · began \(formatted(start.startDate))")
                        .font(TPFont.ui(11.5))
                        .foregroundColor(.tpCreamFaint)
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.tpCreamFaint)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Track

    private func track(_ start: ChallengeService.StartLine) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                let width = geometry.size.width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.tpInkWell)
                        .frame(height: 6)

                    // The people who were already here, clustered at the start.
                    ForEach(Array(start.members.enumerated()), id: \.element.id) { index, member in
                        let ratio = start.totalDays > 1
                            ? Double(member.dayIndex) / Double(start.totalDays - 1)
                            : 0
                        let offset = width * ratio
                        let stacked = Double(index % 3) * 5

                        Circle()
                            .fill(member.isMe ? accent : Color.tpCreamFaint)
                            .frame(width: member.isMe ? 12 : 8, height: member.isMe ? 12 : 8)
                            .overlay(
                                Circle().strokeBorder(Color.tpInk.opacity(0.5), lineWidth: member.isMe ? 1.5 : 0)
                            )
                            .offset(x: max(0, min(offset, width - 12)), y: stacked)
                    }
                }
                .frame(height: 22, alignment: .leading)
            }
            .frame(height: 22)

            HStack {
                Text("Day 1")
                Spacer()
                Text("Day \(start.totalDays)")
            }
            .font(TPFont.ui(10))
            .foregroundColor(.tpCreamFaint)
        }
        .padding(.vertical, 4)
    }

    // MARK: Members

    private func members(_ start: ChallengeService.StartLine) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text.tpLabel("Who is here")

            VStack(spacing: 6) {
                ForEach(start.members) { member in
                    HStack(spacing: 9) {
                        Circle()
                            .fill(member.isMe ? accent : Color.tpCreamFaint.opacity(0.5))
                            .frame(width: 6, height: 6)

                        Text(member.name)
                            .font(TPFont.ui(13, member.isMe ? .semibold : .regular))
                            .foregroundColor(member.isMe ? .tpCream : .tpCreamDim)
                            .lineLimit(1)

                        if member.isMe {
                            TPTag(text: "You", color: accent)
                        }

                        Spacer(minLength: 6)

                        Text(member.dayIndex == 0 ? "From the start" : "Day \(member.dayIndex + 1)")
                            .font(TPFont.ui(11.5))
                            .foregroundColor(.tpCreamFaint)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    // MARK: Empty

    private var signedOut: some View {
        TPEmptyState(
            symbol: "flag",
            title: "Sign in to see this",
            message: "Start lines are drawn from the challenges you have joined.",
            actionTitle: "Sign in",
            action: { session.presentAuth(prompt: "Sign in to see your start lines.") },
            accent: accent
        )
    }

    private var empty: some View {
        TPEmptyState(
            symbol: "flag",
            title: "No challenges yet",
            message: "Join a circle and a challenge comes with it. Everyone begins on the same day.",
            actionTitle: "Browse circles",
            action: { router.select(.circles) },
            accent: accent
        )
    }

    // MARK: Data

    private func reload() {
        guard session.isSignedIn else {
            lines = []
            return
        }

        let built: [Line] = ChallengeService.joined()
            .map { Line(challenge: $0, start: ChallengeService.startLine(for: $0)) }
            .filter { $0.start.hasAnything }

        withAnimation(TPMotion.gentle) {
            lines = built
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
