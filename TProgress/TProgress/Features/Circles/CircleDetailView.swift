import SwiftUI
import CoreData

// MARK: - Circle detail

struct CircleDetailView: View {

    let habit: CDHabit

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var summaries: [CDStageSummary] = []
    @State private var checkIns: [CDCheckIn] = []
    @State private var showingCheckIn = false
    @State private var showingGoal = false
    @State private var showingMinimum = false
    @State private var showingPrompt = false

    private var accent: Color { habit.accent }

    /// This circle's question for the week, shown above the note so the line has
    /// something concrete to answer.
    private var currentPrompt: String? {
        guard habit.isJoined else { return nil }
        let question = PromptService.current(for: habit)
        return question.isEmpty ? nil : question
    }

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: habit.title,
                subtitle: "\(habit.categoryLabel) · \(habit.goalLabel)",
                onBack: { router.pop() },
                trailing: AnyView(menu)
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    presence
                    promptCard
                    weekCard
                    actionButton
                    challengeSection
                    momentsSection
                    recapSection
                    logSection
                }
                .padding(.horizontal, TPMetric.gutter)
                .padding(.bottom, 50)
            }
            .tpDismissKeyboardOnTap()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                // A pushed page covers the tab root, so it paints its own ground. Kept
                // deeper than a tab's so forms and long reads stay comfortable.
                TPBackdropView(style: .deep)
                TPHalo(color: accent, spread: 1.05)
                    .offset(y: -220)
                TPGrain(opacity: 0.04)
            }
            .ignoresSafeArea()
        )
        .onAppear(perform: reload)
        .onChange(of: refresh.practice) { _ in reload() }
        .onChange(of: refresh.feed) { _ in reload() }
        .tpSheet(isPresented: $showingCheckIn) {
            LogCheckInSheet(habit: habit, prompt: currentPrompt) {
                showingCheckIn = false
                // This sheet never used to broadcast, so logging from the circle
                // left Today and Insights holding a stale count.
                RefreshSignal.shared.bumpPractice()
                reload()
            }
        }
        .tpSheet(isPresented: $showingGoal) {
            EditGoalSheet(habit: habit) {
                showingGoal = false
                reload()
            }
        }
        .tpSheet(isPresented: $showingMinimum) {
            MinimumEditorSheet(habit: habit) {
                showingMinimum = false
                reload()
            }
        }
        .tpSheet(isPresented: $showingPrompt) {
            PromptEditorSheet(habit: habit) {
                showingPrompt = false
                reload()
            }
        }
    }

    private var menu: some View {
        Menu {
            Button {
                UIPasteboard.general.string = "\(habit.title) — \(habit.subtitle)"
                tpToast("Copied to clipboard", tone: .success, symbol: "doc.on.doc")
            } label: {
                Label("Copy description", systemImage: "doc.on.doc")
            }

            if habit.isJoined {
                Button {
                    showingGoal = true
                } label: {
                    Label("Goal & frequency", systemImage: "target")
                }

                Button {
                    showingMinimum = true
                } label: {
                    Label(
                        habit.hasMinimum ? "Edit the minimum" : "Set a minimum",
                        systemImage: "arrow.down.circle"
                    )
                }

                if habit.hasMinimum && !habit.todayChecked {
                    Button {
                        logMinimum()
                    } label: {
                        Label("Only the minimum", systemImage: "arrow.down.circle.fill")
                    }
                }

                if habit.todayRested {
                    Button {
                        cancelRest()
                    } label: {
                        Label("Undo today's rest", systemImage: "arrow.uturn.backward")
                    }
                } else if !habit.todayChecked {
                    Button {
                        declareRest()
                    } label: {
                        Label("Rest today", systemImage: "moon.zzz")
                    }
                }

                Button {
                    showingPrompt = true
                } label: {
                    Label("This week's question", systemImage: "questionmark.bubble")
                }

                Button {
                    router.push(.backfill)
                } label: {
                    Label("Fill in a day", systemImage: "clock.arrow.circlepath")
                }

                if let id = habit.id {
                    Button {
                        router.push(.focus(id))
                    } label: {
                        Label("Start a focus session", systemImage: "timer")
                    }
                }
            }

            if habit.isJoined {
                Button(role: .destructive) {
                    habit.isJoined = false
                    CoreDataStack.shared.save()
                    tpToast("Left \(habit.title)", tone: .neutral, symbol: "arrow.left")
                    router.pop()
                } label: {
                    Label("Leave circle", systemImage: "arrow.left")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.tpCreamFaint)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 30)
    }

    // MARK: Presence
    //
    // How many others logged here today, as a count and nothing else. The log
    // carries no author, so there is nobody to name and nothing to rank — and
    // the number is derived from the circle's own seed, so it does not move
    // between launches.

    @ViewBuilder
    private var presence: some View {
        if habit.isJoined {
            let company = CompanyService.today(for: habit)

            HStack(spacing: 9) {
                Image(systemName: "person.3")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.tpSky)

                Text(company.line)
                    .font(TPFont.ui(12.5))
                    .foregroundColor(.tpCreamDim)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.tpSky.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Color.tpSky.opacity(0.22), lineWidth: 1)
            )
        }
    }

    // MARK: Prompt

    @ViewBuilder
    private var promptCard: some View {
        if let question = currentPrompt {
            VStack(alignment: .leading, spacing: 11) {
                Text.tpLabel("This week's question")

                Text(question)
                    .font(TPFont.display(16, .bold))
                    .foregroundColor(.tpCream)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                Button {
                    TPHaptic.tap()
                    showingCheckIn = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11, weight: .bold))
                        Text("Answer it")
                            .font(TPFont.ui(12.5, .semibold))
                    }
                    .foregroundColor(.tpOnAccent)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Capsule(style: .continuous).fill(accent))
                }
                .buttonStyle(.plain)
            }
            .padding(15)
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
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 18) {
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    TPRing(
                        progress: habit.progress,
                        size: 104,
                        lineWidth: 10,
                        colors: [accent, accent.opacity(0.45)]
                    )

                    VStack(spacing: 0) {
                        Text("\(Int(habit.progress * 100))")
                            .font(TPFont.figure(29, .heavy))
                            .foregroundColor(.tpCream)
                        Text.tpLabel("percent", size: 8, tracking: 1.1)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    statLine(symbol: "flame.fill", tint: .tpSun, value: "\(habit.streak)", label: "day streak")
                    statLine(symbol: "person.2.fill", tint: .tpMint, value: formattedMembers, label: "members")
                    statLine(symbol: "clock.fill", tint: .tpLilac, value: formattedMinutes, label: "logged")
                }

                Spacer(minLength: 0)
            }

            Text(habit.subtitle)
                .font(TPFont.display(16.5))
                .foregroundColor(.tpCream.opacity(0.9))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private func statLine(symbol: String, tint: Color, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 16)

            Text(value)
                .font(TPFont.figure(17, .heavy))
                .foregroundColor(.tpCream)

            Text(label)
                .font(TPFont.ui(12.5))
                .foregroundColor(.tpCreamFaint)
        }
    }

    // MARK: Week

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text.tpLabel("Last seven days")
                Spacer()
                Text("\(habit.weekValues.filter { $0 > 0 }.count) of 7")
                    .font(TPFont.figure(12, .bold))
                    .foregroundColor(accent)
            }

            TPWeekColumns(
                values: habit.weekAmounts,
                labels: weekLabels,
                color: accent,
                height: 68
            )
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

    private var weekLabels: [String] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return "" }
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEEE"
            return formatter.string(from: day)
        }
    }

    // MARK: Action

    @ViewBuilder
    private var actionButton: some View {
        if habit.isJoined {
            VStack(spacing: 8) {
                TPPrimaryButton(
                    title: habit.todayChecked ? "Logged today" : "Log today",
                    symbol: habit.todayChecked ? "checkmark.circle.fill" : "plus.circle.fill"
                ) {
                    session.withAuth(prompt: "Sign in to log today.") {
                        // Already logged: the button becomes the way in to the
                        // detail, rather than a second tap that does nothing.
                        guard !habit.todayChecked else {
                            showingCheckIn = true
                            return
                        }
                        HabitService.quickLog(habit)
                        TPHaptic.success()
                        tpToast("Logged today", tone: .success, symbol: "checkmark")
                        RefreshSignal.shared.bumpPractice()
                        reload()
                    }
                }

                TPQuietButton(
                    title: habit.todayChecked ? "Edit today's log" : "Log with details"
                ) {
                    session.withAuth(prompt: "Sign in to log today.") {
                        showingCheckIn = true
                    }
                }
            }
        } else {
            TPPrimaryButton(title: "Join \(habit.title)", symbol: "person.badge.plus") {
                session.withAuth(prompt: "Sign in to join \(habit.title).") {
                    habit.isJoined = true
                    CoreDataStack.shared.save()
                    TPHaptic.success()
                    tpToast("Joined \(habit.title)", tone: .success, symbol: "checkmark")
                }
            }
        }
    }

    // MARK: Challenge

    @ViewBuilder
    private var challengeSection: some View {
        if let challenge = ChallengeService.open(of: habit) {
            VStack(alignment: .leading, spacing: 12) {
                TPSectionHeader(label: "Together", title: "This circle's challenge")

                ChallengeCard(challenge: challenge) {
                    if let id = challenge.id { router.push(.challenge(id)) }
                }
            }
        }
    }

    // MARK: Moments
    //
    // Posts tagged to this circle and the account's own check-ins, merged into
    // one timeline. Check-ins carry no author, so the seeded ones are left out
    // rather than attributed to somebody who did not write them.

    @ViewBuilder
    private var momentsSection: some View {
        let moments = CommunityService.moments(in: habit)

        if !moments.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                TPSectionHeader(label: "In the circle", title: "What has been going on")

                ForEach(moments) { moment in
                    switch moment.kind {
                    case .post(let post):
                        CompactPostRow(post: post) {
                            if let id = post.id { router.push(.post(id)) }
                        }

                    case .checkIn(let entry):
                        CheckInRow(entry: entry, accent: accent)
                    }
                }
            }
        }
    }

    // MARK: Recaps

    @ViewBuilder
    private var recapSection: some View {
        if !summaries.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                TPSectionHeader(label: "Stage recaps", title: "How it is going")

                VStack(spacing: 10) {
                    ForEach(summaries, id: \.objectID) { summary in
                        Button {
                            if let id = habit.id { router.push(.recap(id)) }
                        } label: {
                            recapRow(summary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func recapRow(_ summary: CDStageSummary) -> some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .strokeBorder(accent.opacity(0.25), lineWidth: 3)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: CGFloat(summary.completionRate))
                    .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(summary.completionRate * 100))")
                    .font(TPFont.figure(13, .heavy))
                    .foregroundColor(.tpCream)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(summary.heading)
                    .font(TPFont.ui(14.5, .semibold))
                    .foregroundColor(.tpCream)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text("\(summary.periodLabel) · \(summary.totalLabel)")
                    .font(TPFont.ui(11.5))
                    .foregroundColor(.tpCreamFaint)
            }

            Spacer(minLength: 8)

            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(accent)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
    }

    // MARK: Log

    @ViewBuilder
    private var logSection: some View {
        if !checkIns.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                TPSectionHeader(label: "Recent log", title: "Days you showed up")

                VStack(spacing: 0) {
                    ForEach(checkIns.prefix(12), id: \.objectID) { entry in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(accent)
                                .frame(width: 7, height: 7)

                            Text(dayLabel(entry.date))
                                .font(TPFont.ui(13.5, .medium))
                                .foregroundColor(.tpCream)

                            Spacer(minLength: 8)

                            if entry.amountValue > 0 {
                                Text("\(Int(entry.amountValue)) \(entry.amountUnit ?? "")")
                                    .font(TPFont.figure(12, .semibold))
                                    .foregroundColor(.tpCreamDim)
                            }
                        }
                        .padding(.vertical, 11)

                        if entry.objectID != checkIns.prefix(12).last?.objectID {
                            TPFadeRule()
                        }
                    }
                }
                .padding(.horizontal, 15)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.tpInkRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.tpLine, lineWidth: 1)
                )
            }
        }
    }

    private func dayLabel(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "'Today'" : "EEEE, d MMM"
        return formatter.string(from: date)
    }

    // MARK: Data

    private func reload() {
        summaries = habit.summaries.sorted {
            ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
        }
        checkIns = habit.sortedCheckIns
    }

    // MARK: Actions

    private func logMinimum() {
        session.withAuth(prompt: "Sign in to log today.") {
            guard HabitService.logMinimum(habit) != nil else { return }
            TPHaptic.success()
            tpToast("Minimum logged — that counts", tone: .success, symbol: "arrow.down.circle")
            RefreshSignal.shared.bumpPractice()
            reload()
        }
    }

    private func declareRest() {
        session.withAuth(prompt: "Sign in to set a rest day.") {
            guard HabitService.declareRest(habit) else {
                tpToast("That day cannot be rested", tone: .warning, symbol: "exclamationmark")
                return
            }
            TPHaptic.success()
            tpToast("Today is set aside", tone: .success, symbol: "moon.zzz")
            RefreshSignal.shared.bumpPractice()
            reload()
        }
    }

    private func cancelRest() {
        session.withAuth(prompt: "Sign in to change this.") {
            HabitService.cancelRest(habit)
            TPHaptic.tap()
            tpToast("Rest removed", tone: .neutral, symbol: "arrow.uturn.backward")
            RefreshSignal.shared.bumpPractice()
            reload()
        }
    }

    private var formattedMembers: String {
        habit.memberCount >= 1000
            ? String(format: "%.1fk", Double(habit.memberCount) / 1000)
            : "\(habit.memberCount)"
    }

    private var formattedMinutes: String {
        let minutes = Int(habit.totalMinutes)
        if minutes >= 60 {
            return String(format: "%.1fh", Double(minutes) / 60)
        }
        return "\(minutes)m"
    }
}
