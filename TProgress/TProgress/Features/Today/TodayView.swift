import SwiftUI
import CoreData

// MARK: - Feed filter

private enum FeedFilter: String, CaseIterable, Identifiable {

    case all
    case progress
    case recaps
    case following

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:       return "Everything"
        case .progress:  return "Progress"
        case .recaps:    return "Recaps"
        case .following: return "Following"
        }
    }

    var emptyMessage: String {
        switch self {
        case .all:       return "Nothing has been logged yet. Be the first."
        case .progress:  return "No progress posts in this window yet."
        case .recaps:    return "No stage recaps yet. They appear once a circle hits a milestone."
        case .following: return "Follow a few people and their work will show up here."
        }
    }
}

// MARK: - Today

struct TodayView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var refresh = RefreshSignal.shared
    @ObservedObject private var focus = FocusTimerService.shared

    @State private var filter: FeedFilter = .all
    @State private var posts: [CDPost] = []
    @State private var hasLoaded = false

    /// The circle whose check-in sheet is open, if any.
    @State private var detailHabit: CDHabit?

    @Namespace private var segment

    /// The home feed is a window, not a timeline. Six posts is the whole page:
    /// enough to see who is moving and what they logged, short enough that the
    /// page still ends somewhere. Everything older stays on each profile shelf.
    private let homeLimit = 6

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 18) {
                    header
                    hero
                    filterBar
                    feed
                }
                .padding(.bottom, TPMetric.dockClearance)
            }
            .refreshable { reload(animated: true) }
            .tpDismissKeyboardOnTap()
        }
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            reload(animated: false)
        }
        .onChange(of: filter) { _ in reload(animated: true) }
        .onChange(of: refresh.feed) { _ in reload(animated: false) }
        .onChange(of: refresh.practice) { _ in reload(animated: false) }
        .tpSheet(isPresented: detailBinding) { checkInSheet }
    }

    // MARK: Check-in sheet

    private var detailBinding: Binding<Bool> {
        Binding(
            get: { detailHabit != nil },
            set: { if !$0 { detailHabit = nil } }
        )
    }

    @ViewBuilder
    private var checkInSheet: some View {
        if let habit = detailHabit {
            LogCheckInSheet(habit: habit) {
                detailHabit = nil
                RefreshSignal.shared.bumpPractice()
            }
        }
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            // The shell paints the gradient ground; pages stay transparent so it
            // reads continuously across a push.
            Color.clear
            TPHalo(color: .tpEmber, spread: 1.10)
                .offset(x: -90, y: -230)
            TPGrain(opacity: 0.04)
        }
        .ignoresSafeArea()
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text.tpLabel(todayLabel, size: 10, tracking: 1.8)

                Text(greeting)
                    .font(TPFont.display(29, .heavy))
                    .foregroundColor(.tpCream)
            }

            Spacer(minLength: 8)

            // A run in flight is worth showing on the home page, so it can be
            // picked back up without hunting for the circle.
            if let running = focus.habit, focus.isRunning {
                runningPill(running)
            }

            streakBadge
        }
        .padding(.horizontal, TPMetric.gutter)
        .padding(.top, 10)
    }

    private func runningPill(_ habit: CDHabit) -> some View {
        Button {
            if let id = habit.id { router.push(.focus(id)) }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "timer")
                    .font(.system(size: 10, weight: .bold))

                Text(focus.clockLabel)
                    .font(TPFont.figure(12, .bold))
                    .monospacedDigit()
            }
            .foregroundColor(habit.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(habit.accent.opacity(0.14))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(habit.accent.opacity(0.34), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var streakBadge: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.tpSun)
                Text("\(currentStreak)")
                    .font(TPFont.figure(19, .heavy))
                    .foregroundColor(.tpCream)
            }
            Text.tpLabel("day streak", size: 8.5, tracking: 1.1)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.tpSun.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.tpSun.opacity(0.26), lineWidth: 1)
        )
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    TPRing(
                        progress: joinedHabits.isEmpty ? 0 : todayRatio,
                        size: 78,
                        lineWidth: 8,
                        colors: [.tpSun, .tpEmber]
                    )
                    VStack(spacing: 0) {
                        Text("\(checkedTodayCount)")
                            .font(TPFont.figure(23, .heavy))
                            .foregroundColor(.tpCream)
                        Text.tpLabel("of \(joinedHabits.count)", size: 8, tracking: 0.8)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(joinedHabits.isEmpty ? "No circles yet" : "Today's circles")
                        .font(TPFont.display(19, .bold))
                        .foregroundColor(.tpCream)

                    Text(joinedHabits.isEmpty
                         ? "Join a circle and it will appear here every morning."
                         : "\(checkedTodayCount) logged, \(max(0, joinedHabits.count - checkedTodayCount)) to go. Small counts.")
                        .font(TPFont.ui(13))
                        .foregroundColor(.tpCreamDim)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if !joinedHabits.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(joinedHabits, id: \.objectID) { habit in
                            quickCheckIn(habit)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(TPGradient.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
        .tpShadow(20, y: 12, opacity: 0.34)
        .padding(.horizontal, TPMetric.gutter)
    }

    private func quickCheckIn(_ habit: CDHabit) -> some View {
        Button(action: {
            session.withAuth(prompt: "Sign in to log today.") {
                // A tap is the cheap path: it marks the day and nothing else.
                // Tapping a circle that is already logged opens the sheet, so
                // one control both marks the day and lets it be described.
                if habit.todayChecked {
                    detailHabit = habit
                } else {
                    logNow(habit)
                }
            }
        }) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(habit.todayChecked ? habit.accent : Color.tpInkWell)
                        .frame(width: 24, height: 24)

                    if habit.todayChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.tpOnAccent)
                    } else {
                        TPIcon(name: habit.iconAssetName, fallbackSymbol: habit.symbol, size: 13, tint: habit.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(habit.title)
                        .font(TPFont.ui(12.5, .semibold))
                        .foregroundColor(.tpCream)
                        .lineLimit(1)

                    Text(habit.todayChecked ? "Logged" : habit.cadenceLabel)
                        .font(TPFont.ui(10))
                        .foregroundColor(habit.todayChecked ? habit.accent : .tpCreamFaint)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(habit.todayChecked ? habit.accent.opacity(0.14) : Color.tpInkWell)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        habit.todayChecked ? habit.accent.opacity(0.5) : Color.tpLine,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                session.withAuth(prompt: "Sign in to log today.") {
                    detailHabit = habit
                }
            } label: {
                Label("Log with details", systemImage: "square.and.pencil")
            }

            if habit.todayChecked {
                Button(role: .destructive) {
                    session.withAuth(prompt: "Sign in to log today.") {
                        undoToday(habit)
                    }
                } label: {
                    Label("Remove today", systemImage: "arrow.uturn.backward")
                }
            }
        }
    }

    // MARK: Filter

    private var filterBar: some View {
        TPSegmented(
            items: FeedFilter.allCases,
            selection: $filter,
            title: \.title,
            namespace: segment
        )
        .padding(.horizontal, TPMetric.gutter)
    }

    // MARK: Feed

    @ViewBuilder
    private var feed: some View {
        if posts.isEmpty {
            emptyState
        } else {
            VStack(spacing: 14) {
                BentoFeed(posts: Array(posts.prefix(homeLimit))) { target in
                    GiftPresenter.shared.present(target)
                }

                endOfFeed
            }
            .padding(.horizontal, TPMetric.gutter)
        }
    }

    private var emptyState: some View {
        TPEmptyState(
            glyph: AnyView(
                GlyphSpark().stroke(Color.tpEmber, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            ),
            title: "Nothing logged yet",
            message: filter.emptyMessage,
            actionTitle: session.isSignedIn ? "Log something" : "Sign in to post",
            action: {
                if session.isSignedIn {
                    router.push(.compose)
                } else {
                    session.presentAuth(prompt: "Sign in to start your own log.")
                }
            }
        )
        .padding(.horizontal, TPMetric.gutter)
    }

    private var endOfFeed: some View {
        VStack(spacing: 9) {
            TPMark(showsBaseline: false)
                .stroke(Color.tpLine, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 26, height: 26)

            Text.tpLabel(caughtUpLabel, size: 9.5, tracking: 1.4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }

    /// Says what the window actually is, instead of claiming the feed is
    /// finished when there are twenty more logs sitting behind it.
    private var caughtUpLabel: String {
        posts.count > homeLimit ? "The \(homeLimit) newest · older logs on profiles" : "That's everything for now"
    }

    // MARK: Data

    private var joinedHabits: [CDHabit] {
        CoreDataStack.shared.fetch(
            CDHabit.self,
            predicate: NSPredicate(format: "isJoined == YES"),
            sortBy: [TPSort.byName]
        )
    }

    private var checkedTodayCount: Int {
        joinedHabits.filter(\.todayChecked).count
    }

    private var todayRatio: Double {
        guard !joinedHabits.isEmpty else { return 0 }
        return Double(checkedTodayCount) / Double(joinedHabits.count)
    }

    private var currentStreak: Int {
        if let user = session.currentUser, user.streak > 0 {
            return Int(user.streak)
        }
        return joinedHabits.map { Int($0.streak) }.max() ?? 0
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<18: return "Good afternoon"
        case 18..<23: return "Good evening"
        default:      return "Still up"
        }
    }

    private var todayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: Date())
    }

    // MARK: Loading

    private func reload(animated: Bool) {
        let predicate: NSPredicate?
        switch filter {
        case .all:
            predicate = nil
        case .progress:
            predicate = NSPredicate(format: "kindRaw != %@", PostKind.summary.rawValue)
        case .recaps:
            predicate = NSPredicate(format: "kindRaw == %@", PostKind.summary.rawValue)
        case .following:
            predicate = NSPredicate(format: "author.isFollowedByMe == YES OR author.isCurrentUser == YES")
        }

        let fetched = CoreDataStack.shared.fetch(
            CDPost.self,
            predicate: predicate,
            sortBy: [TPSort.newestPost]
        )

        if animated {
            withAnimation(TPMotion.gentle) {
                posts = fetched
            }
        } else {
            posts = fetched
        }
    }

    private func logNow(_ habit: CDHabit) {
        HabitService.quickLog(habit)
        TPHaptic.success()
        tpToast("Logged for today", tone: .success, symbol: "checkmark")
        RefreshSignal.shared.bumpPractice()
    }

    private func undoToday(_ habit: CDHabit) {
        HabitService.removeToday(habit)
        TPHaptic.tap()
        RefreshSignal.shared.bumpPractice()
    }
}

