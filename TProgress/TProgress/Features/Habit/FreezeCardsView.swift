import SwiftUI
import CoreData

// MARK: - Freeze cards
//
// Where the streak is protected. Cards are only ever earned — a rung on the
// ladder or a week kept whole — and spent by hand, on a named day, so nothing
// disappears without the person watching it happen.

struct FreezeCardsView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var milestones = MilestonePresenter.shared

    @State private var balance = 0
    @State private var streak = 0
    @State private var broken: [CDHabit] = []

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "Freeze cards",
                subtitle: "Earned, never bought",
                onBack: { router.pop() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    balanceCard
                    earningCard
                    ladderCard
                    restoreSection
                }
                .padding(.horizontal, TPMetric.gutter)
                .padding(.bottom, 50)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                TPBackdropView(style: .deep)
                TPHalo(color: .tpSky, spread: 1.05).offset(y: -220)
                TPGrain(opacity: 0.04)
            }
            .ignoresSafeArea()
        )
        .onAppear(perform: reload)
        .onChange(of: milestones.milestone) { _ in reload() }
    }

    // MARK: Balance

    private var balanceCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(TPGradient.accent(.tpSky))
                    .frame(width: 96, height: 96)
                    .tpEmberGlow(.tpSky, strength: 0.5)

                Circle()
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    .frame(width: 96, height: 96)

                Image(systemName: "snowflake")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.tpInk.opacity(0.82))
            }

            Text("\(balance)")
                .font(TPFont.display(40, .heavy))
                .foregroundColor(.tpCream)

            Text("A card buys back one missed day, so a run that should still be alive stays alive.")
                .font(TPFont.ui(13))
                .foregroundColor(.tpCreamDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(TPGradient.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.tpSky.opacity(0.24), lineWidth: 1)
        )
    }

    // MARK: Earning

    private var earningCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text.tpLabel("How they are earned")

            earningRow(
                symbol: "flame.fill",
                tint: .tpSun,
                title: "A milestone",
                detail: "One card each time the streak crosses a rung below."
            )

            TPFadeRule()

            earningRow(
                symbol: "calendar.badge.checkmark",
                tint: .tpMint,
                title: "A week kept whole",
                detail: "Every day of a calendar week logged, in any circle."
            )

            TPFadeRule()

            Text("They cannot be bought, and holding more than \(HabitService.freezeCardCap) does nothing — the cap is deliberate.")
                .font(TPFont.ui(11.5))
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

    private func earningRow(symbol: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 34, height: 34)

                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(TPFont.ui(14, .semibold))
                    .foregroundColor(.tpCream)

                Text(detail)
                    .font(TPFont.ui(12))
                    .foregroundColor(.tpCreamFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Ladder

    private var ladderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text.tpLabel("The ladder")

            TPStreakDots(
                total: Milestone.ladder.count,
                filled: Milestone.ladder.filter { $0 <= streak }.count,
                color: .tpSun,
                dotSize: 10
            )

            HStack {
                ForEach(Milestone.ladder, id: \.self) { rung in
                    Text("\(rung)")
                        .font(TPFont.figure(10, .bold))
                        .foregroundColor(rung <= streak ? .tpSun : .tpCreamFaint)
                        .frame(maxWidth: .infinity)
                }
            }

            Text(
                Milestone.next(after: streak).map { "Next rung at \($0) days. You are on \(streak)." }
                    ?? "Every rung on the ladder is behind you."
            )
            .font(TPFont.ui(12))
            .foregroundColor(.tpCreamDim)
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

    // MARK: Restore

    @ViewBuilder
    private var restoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TPSectionHeader(label: "Broken runs", title: "Missing yesterday")

            if broken.isEmpty {
                Text("Nothing is missing yesterday. Every circle you are in has its log intact.")
                    .font(TPFont.ui(12.5))
                    .foregroundColor(.tpCreamFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.tpInkRaised)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.tpLine, lineWidth: 1)
                    )
            } else {
                ForEach(broken, id: \.objectID) { habit in
                    restoreRow(habit)
                }
            }
        }
    }

    private func restoreRow(_ habit: CDHabit) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(habit.accent.opacity(0.16))
                    .frame(width: 40, height: 40)

                TPIcon(
                    name: habit.iconAssetName,
                    fallbackSymbol: habit.symbol,
                    size: 17,
                    tint: habit.accent
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(habit.title)
                    .font(TPFont.ui(14.5, .semibold))
                    .foregroundColor(.tpCream)

                Text("\(habit.streak) day streak, one day short")
                    .font(TPFont.ui(11.5))
                    .foregroundColor(.tpCreamFaint)
            }

            Spacer(minLength: 8)

            Button {
                restore(habit)
            } label: {
                Text("Restore")
                    .font(TPFont.ui(12.5, .bold))
                    .foregroundColor(balance > 0 ? .tpOnAccent : .tpCreamFaint)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .fill(balance > 0 ? AnyShapeStyle(TPGradient.accent(.tpSky)) : AnyShapeStyle(Color.tpInkWell))
                    )
            }
            .buttonStyle(.plain)
            .disabled(balance <= 0)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
    }

    // MARK: Data

    private func reload() {
        balance = Int(session.currentUser?.freezeTokens ?? 0)
        streak = Int(session.currentUser?.streak ?? 0)
        broken = CoreDataStack.shared
            .fetch(CDHabit.self, predicate: NSPredicate(format: "isJoined == YES"), sortBy: [TPSort.byName])
            .filter { HabitService.missedYesterday($0) }
    }

    private func restore(_ habit: CDHabit) {
        guard HabitService.restoreYesterday(habit) else {
            tpToast("No freeze card to spend", tone: .warning, symbol: "snowflake")
            return
        }
        TPHaptic.success()
        tpToast("Yesterday restored", tone: .success, symbol: "snowflake")
        RefreshSignal.shared.bumpPractice()
        reload()
    }
}
