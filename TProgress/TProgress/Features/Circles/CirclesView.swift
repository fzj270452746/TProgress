import SwiftUI
import CoreData

// MARK: - Circles

struct CirclesView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var joined: [CDHabit] = []
    @State private var discover: [CDHabit] = []
    @State private var challenges: [CDChallenge] = []

    @Namespace private var segment

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    challengeSection
                    joinedSection
                    discoverSection
                }
                .padding(.bottom, TPMetric.dockClearance)
            }
            .tpDismissKeyboardOnTap()
        }
        .onAppear(perform: reload)
        .onChange(of: refresh.practice) { _ in reload() }
    }

    // MARK: Challenges
    //
    // Shown before the circles themselves: a shared goal is the most time-bound
    // thing on the page, and the only part of it that can run out.

    @ViewBuilder
    private var challengeSection: some View {
        if !challenges.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                TPSectionHeader(label: "Running now", title: "Challenges")

                ForEach(challenges, id: \.objectID) { challenge in
                    ChallengeCard(challenge: challenge) {
                        if let id = challenge.id { router.push(.challenge(id)) }
                    }
                }
            }
            .padding(.horizontal, TPMetric.gutter)
        }
    }

    private var background: some View {
        ZStack {
            // The shell paints the gradient ground; pages stay transparent so it
            // reads continuously across a push.
            Color.clear
            TPHalo(color: .tpMint, spread: 1.05)
                .offset(x: 110, y: -240)
            TPGrain(opacity: 0.04)
        }
        .ignoresSafeArea()
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text.tpLabel("Circles", size: 10, tracking: 1.8)

            Text("The groups you keep")
                .font(TPFont.display(29, .heavy))
                .foregroundColor(.tpCream)

            Text("A circle is a shared practice, not a leaderboard. Members log the same small thing and see each other do it.")
                .font(TPFont.ui(13.5))
                .foregroundColor(.tpCreamDim)
                .lineSpacing(3.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, TPMetric.gutter)
        .padding(.top, 12)
    }

    // MARK: Joined

    @ViewBuilder
    private var joinedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TPSectionHeader(label: "Yours", title: "In progress")
                .padding(.horizontal, TPMetric.gutter)

            if joined.isEmpty {
                TPEmptyState(
                    glyph: AnyView(
                        GlyphCircles().stroke(Color.tpMint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    ),
                    title: "No circles joined",
                    message: "Pick one below. You can leave whenever it stops being useful.",
                    accent: .tpMint
                )
                .padding(.horizontal, TPMetric.gutter)
            } else {
                VStack(spacing: 14) {
                    ForEach(joined, id: \.objectID) { habit in
                        CircleCard(habit: habit) {
                            reload()
                        } onOpen: {
                            open(habit)
                        }
                    }
                }
                .padding(.horizontal, TPMetric.gutter)
            }
        }
    }

    // MARK: Discover

    @ViewBuilder
    private var discoverSection: some View {
        if !discover.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                TPSectionHeader(label: "Discover", title: "Circles to join")
                    .padding(.horizontal, TPMetric.gutter)

                VStack(spacing: 10) {
                    ForEach(discover, id: \.objectID) { habit in
                        DiscoverRow(habit: habit) {
                            join(habit)
                        } onOpen: {
                            open(habit)
                        }
                    }
                }
                .padding(.horizontal, TPMetric.gutter)
            }
        }
    }

    // MARK: Actions

    private func reload() {
        joined = CoreDataStack.shared.fetch(
            CDHabit.self,
            predicate: NSPredicate(format: "isJoined == YES"),
            sortBy: [TPSort.byName]
        )
        discover = CoreDataStack.shared.fetch(
            CDHabit.self,
            predicate: NSPredicate(format: "isJoined == NO"),
            sortBy: [NSSortDescriptor(key: "memberCount", ascending: false)]
        )
        challenges = ChallengeService.joined()
    }

    private func open(_ habit: CDHabit) {
        guard let id = habit.id else { return }
        router.push(.circle(id))
    }

    private func join(_ habit: CDHabit) {
        session.withAuth(prompt: "Sign in to join \(habit.title).") {
            withAnimation(TPMotion.spring) {
                habit.isJoined = true
            }
            CoreDataStack.shared.save()
            // A circle joined mid-session gets its challenge straight away
            // rather than waiting for the next launch.
            ChallengeService.seedIfNeeded()
            TPHaptic.success()
            tpToast("Joined \(habit.title)", tone: .success, symbol: "checkmark")
            reload()
        }
    }
}

// MARK: - Circle card

struct CircleCard: View {

    let habit: CDHabit
    let onCheckIn: () -> Void
    let onOpen: () -> Void

    @ObservedObject private var session = AppSession.shared

    private var accent: Color { habit.accent }

    private let weekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 15) {
                topRow
                metrics
                TPWeekColumns(values: habit.weekAmounts, labels: weekLabels, color: accent)
                checkInButton
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: TPMetric.cardRadius, style: .continuous)
                    .fill(TPGradient.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TPMetric.cardRadius, style: .continuous)
                    .strokeBorder(accent.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var topRow: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.16))
                    .frame(width: 44, height: 44)

                TPIcon(name: habit.iconAssetName, fallbackSymbol: habit.symbol, size: 21, tint: accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(habit.title)
                    .font(TPFont.display(19, .bold))
                    .foregroundColor(.tpCream)

                Text("\(habit.categoryLabel) · \(habit.cadenceLabel)")
                    .font(TPFont.ui(12))
                    .foregroundColor(.tpCreamFaint)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.tpCreamFaint)
        }
    }

    private var metrics: some View {
        HStack(spacing: 16) {
            ZStack {
                TPRing(
                    progress: habit.progress,
                    size: 62,
                    lineWidth: 6.5,
                    colors: [accent, accent.opacity(0.5)],
                    showsTicks: false
                )
                Text("\(Int(habit.progress * 100))%")
                    .font(TPFont.figure(15, .heavy))
                    .foregroundColor(.tpCream)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.tpSun)
                    Text("\(habit.streak)")
                        .font(TPFont.figure(16, .heavy))
                        .foregroundColor(.tpCream)
                    Text("day streak")
                        .font(TPFont.ui(12))
                        .foregroundColor(.tpCreamFaint)
                }

                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.tpMint)
                    Text(formattedMembers)
                        .font(TPFont.figure(13, .semibold))
                        .foregroundColor(.tpCreamDim)
                    Text("members")
                        .font(TPFont.ui(12))
                        .foregroundColor(.tpCreamFaint)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var checkInButton: some View {
        Button(action: {
            session.withAuth(prompt: "Sign in to log today.") { onCheckIn() }
        }) {
            HStack(spacing: 8) {
                Image(systemName: habit.todayChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))

                Text(habit.todayChecked ? "Logged today" : "Log today")
                    .font(TPFont.ui(14.5, .semibold))
            }
            .foregroundColor(habit.todayChecked ? .tpOnAccent : accent)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                Capsule(style: .continuous)
                    .fill(habit.todayChecked
                          ? AnyShapeStyle(TPGradient.accent(accent))
                          : AnyShapeStyle(accent.opacity(0.12)))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(accent.opacity(habit.todayChecked ? 0 : 0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var weekLabels: [String] {
        // Oldest first, today last.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return "" }
            let index = calendar.component(.weekday, from: day) - 1
            return weekdayLabels[(index + 6) % 7]
        }
    }

    private var formattedMembers: String {
        habit.memberCount >= 1000
            ? String(format: "%.1fk", Double(habit.memberCount) / 1000)
            : "\(habit.memberCount)"
    }
}

// MARK: - Discover row

struct DiscoverRow: View {

    let habit: CDHabit
    let onJoin: () -> Void
    let onOpen: () -> Void

    private var accent: Color { habit.accent }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(accent.opacity(0.14))
                        .frame(width: 42, height: 42)

                    TPIcon(name: habit.iconAssetName, fallbackSymbol: habit.symbol, size: 20, tint: accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(habit.title)
                        .font(TPFont.ui(15, .semibold))
                        .foregroundColor(.tpCream)

                    Text(habit.subtitle)
                        .font(TPFont.ui(12))
                        .foregroundColor(.tpCreamFaint)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button(action: onJoin) {
                    Text("Join")
                        .font(TPFont.ui(12.5, .semibold))
                        .foregroundColor(.tpOnAccent)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(TPGradient.accent(accent))
                        )
                }
                .buttonStyle(.plain)
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
        .buttonStyle(.plain)
    }
}
