import SwiftUI
import CoreData

// MARK: - Challenge detail
//
// One circle's shared goal, opened up. The bar is the whole story: what the
// group has covered between them. The list of people below it is alphabetical
// and carries no ordering by contribution, because a shared practice is not a
// ranking and the app says so on the circles page.

struct ChallengeDetailView: View {

    let challenge: CDChallenge

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var participants: [(user: CDUser, days: Int)] = []

    private var accent: Color { challenge.accent }

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: challenge.kind.label,
                subtitle: challenge.habit?.title,
                onBack: { router.pop() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    progressCard
                    if challenge.kind == .relay21 { relayCard }
                    participantsCard
                    actionButton
                }
                .padding(.horizontal, TPMetric.gutter)
                .padding(.bottom, 50)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                TPBackdropView(style: .deep)
                TPHalo(color: accent, spread: 1.05).offset(y: -220)
                TPGrain(opacity: 0.04)
            }
            .ignoresSafeArea()
        )
        .onAppear(perform: reload)
        .onChange(of: refresh.practice) { _ in reload() }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(challenge.heading)
                .font(TPFont.display(26, .heavy))
                .foregroundColor(.tpCream)
                .fixedSize(horizontal: false, vertical: true)

            Text(challenge.blurbText)
                .font(TPFont.ui(13.5))
                .foregroundColor(.tpCreamDim)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                TPTag(text: challenge.isActive ? "\(challenge.daysRemaining) days left" : "Closed",
                      color: challenge.isActive ? accent : .tpCreamFaint)

                if let habit = challenge.habit {
                    TPTag(text: habit.goalLabel, color: .tpMint)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: Progress

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    TPRing(
                        progress: challenge.progress,
                        size: 96,
                        lineWidth: 10,
                        colors: [accent, accent.opacity(0.45)]
                    )

                    VStack(spacing: 0) {
                        Text("\(Int((challenge.progress * 100).rounded()))")
                            .font(TPFont.figure(26, .heavy))
                            .foregroundColor(.tpCream)
                        Text.tpLabel("together", size: 8, tracking: 1)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    TPStatTile(
                        value: "\(challenge.covered)",
                        caption: "Covered",
                        color: accent,
                        symbol: "person.3"
                    )
                    TPStatTile(
                        value: "\(challenge.myDays)",
                        caption: "Yours",
                        color: .tpMint,
                        symbol: "person.fill.checkmark"
                    )
                }

                Spacer(minLength: 0)
            }

            TPMeter(progress: challenge.progress, height: 10, color: accent)

            Text(challenge.progressLabel)
                .font(TPFont.ui(12))
                .foregroundColor(.tpCreamFaint)
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
    }

    // MARK: Relay

    private var relayCard: some View {
        let covered = challenge.coveredDays

        return VStack(alignment: .leading, spacing: 14) {
            Text.tpLabel("The chain")

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                spacing: 6
            ) {
                ForEach(Array(covered.enumerated()), id: \.offset) { index, isOn in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isOn ? accent : Color.tpInkWell)
                        .frame(height: 22)
                        .overlay(
                            Text("\(index + 1)")
                                .font(TPFont.figure(9.5, .bold))
                                .foregroundColor(isOn ? .tpInk.opacity(0.75) : .tpCreamFaint)
                        )
                }
            }

            Text("A day lights up when anyone in the circle logs it. Twenty-one lit days is the whole ask.")
                .font(TPFont.ui(12))
                .foregroundColor(.tpCreamFaint)
                .fixedSize(horizontal: false, vertical: true)
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

    // MARK: People

    private var participantsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text.tpLabel("In the circle")

                Spacer(minLength: 4)

                Text("no ranking")
                    .font(TPFont.ui(10.5))
                    .foregroundColor(.tpCreamFaint)
            }

            ForEach(participants, id: \.user.objectID) { row in
                HStack(spacing: 11) {
                    TPAvatar(
                        seed: row.user.avatarSeed,
                        name: row.user.name,
                        size: 38,
                        imagePath: row.user.avatarAssetName
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.user.isCurrentUser ? "You" : row.user.name)
                            .font(TPFont.ui(14, .semibold))
                            .foregroundColor(.tpCream)
                            .lineLimit(1)

                        Text(row.user.isCurrentUser ? "Your own log" : "\(row.days) days in")
                            .font(TPFont.ui(11.5))
                            .foregroundColor(.tpCreamFaint)
                    }

                    Spacer(minLength: 6)

                    if row.user.isCurrentUser {
                        TPTag(text: "you", color: accent, filled: true)
                    }
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

    // MARK: Action

    @ViewBuilder
    private var actionButton: some View {
        if challenge.isActive {
            VStack(spacing: 8) {
                if challenge.isJoined {
                    TPOutlineButton(title: "Leave this challenge", symbol: "arrow.left") {
                        ChallengeService.leave(challenge)
                        TPHaptic.tap()
                        tpToast("Left the challenge", tone: .neutral, symbol: "arrow.left")
                        reload()
                    }
                } else {
                    TPPrimaryButton(title: "Join this challenge", symbol: "person.badge.plus") {
                        session.withAuth(prompt: "Sign in to join.") {
                            ChallengeService.join(challenge)
                            TPHaptic.success()
                            tpToast("Joined", tone: .success, symbol: "checkmark")
                            reload()
                        }
                    }
                }
            }
        } else {
            Text("This challenge has closed. Its final numbers stay here.")
                .font(TPFont.ui(12.5))
                .foregroundColor(.tpCreamFaint)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Data

    private func reload() {
        participants = ChallengeService.participants(challenge)
    }
}
