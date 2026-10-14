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

    private var accent: Color { habit.accent }

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
            LogCheckInSheet(habit: habit) {
                showingCheckIn = false
                reload()
            }
        }
        .tpSheet(isPresented: $showingGoal) {
            EditGoalSheet(habit: habit) {
                showingGoal = false
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
                        checkInRow(entry)
                    }
                }
            }
        }
    }

    private func checkInRow(_ entry: CDCheckIn) -> some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 34, height: 34)

                Image(systemName: entry.isFreeze ? "snowflake" : "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.isFreeze ? "Restored with a freeze card" : "Logged \(entry.amountLabel)")
                    .font(TPFont.ui(13.5, .semibold))
                    .foregroundColor(.tpCream)

                if entry.hasNote {
                    Text(entry.noteText)
                        .font(TPFont.ui(12))
                        .foregroundColor(.tpCreamFaint)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 6)

            Text(entry.relativeTime)
                .font(TPFont.ui(11))
                .foregroundColor(.tpCreamFaint)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
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
