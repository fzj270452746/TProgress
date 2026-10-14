import SwiftUI
import CoreData

// MARK: - Chat detail
//
// A thread that carries actions, not just words. Check-ins and gifts appear as
// cards inside the conversation, which is the whole point of the product.

struct ChatDetailView: View {

    let thread: CDConversation

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var caller = CallService.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var messages: [CDMessage] = []
    @State private var draft = ""
    @State private var showsLogSheet = false

    @FocusState private var composerFocused: Bool

    private var peer: CDUser? { thread.peer }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        boundNote

                        ForEach(Array(messages.enumerated()), id: \.element.objectID) { index, message in
                            let previous = index > 0 ? messages[index - 1] : nil

                            if TPTime.shouldShowDaySeparator(previous: previous?.createdAt, current: message.createdAt) {
                                daySeparator(message.createdAt)
                            }

                            // One colour for "me" across every thread — the peer's
                            // accent belongs to their name, not to my bubbles.
                            MessageRow(message: message)
                                .id(message.objectID)
                        }
                    }
                    .padding(.horizontal, TPMetric.gutter)
                    .padding(.vertical, 14)
                }
                .tpDismissKeyboardOnTap()
                .onChange(of: messages.count) { _ in
                    guard let last = messages.last else { return }
                    withAnimation(TPMotion.gentle) {
                        proxy.scrollTo(last.objectID, anchor: .bottom)
                    }
                }
                .onAppear {
                    if let last = messages.last {
                        proxy.scrollTo(last.objectID, anchor: .bottom)
                    }
                }
            }

            composer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                // A pushed page covers the tab root, so it paints its own ground. Kept
                // deeper than a tab's so forms and long reads stay comfortable.
                TPBackdropView(style: .deep)
                TPGrain(opacity: 0.04)
            }
            .ignoresSafeArea()
        )
        .sheet(isPresented: $showsLogSheet) {
            LogToThreadSheet(thread: thread) {
                showsLogSheet = false
                reload()
            }
            .tpSheetPage()
        }
        .onAppear {
            CommunityService.markRead(thread)
            reload()
        }
        .onChange(of: refresh.chats) { _ in reload() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            TPIconButton(symbol: "chevron.left", size: 38) { router.pop() }

            Button(action: openProfile) {
                HStack(spacing: 10) {
                    TPAvatar(
                        seed: peer?.avatarSeed ?? 0,
                        name: peer?.name ?? "?",
                        size: 38,
                        imagePath: peer?.avatarAssetName
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(peer?.name ?? "Someone")
                            .font(TPFont.ui(15.5, .semibold))
                            .foregroundColor(.tpCream)
                            .lineLimit(1)

                        Text(peer?.handle ?? "")
                            .font(TPFont.ui(11.5))
                            .foregroundColor(.tpCreamFaint)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            TPIconButton(symbol: "video.fill", size: 38, tint: .tpEmber) {
                startCall()
            }

            menu
        }
        .padding(.horizontal, TPMetric.gutter)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            TPBarFill(edge: .bottom)
                .overlay(alignment: .bottom) { TPFadeRule() }
                .ignoresSafeArea(edges: .top)
        )
    }

    private var menu: some View {
        Menu {
            Button {
                showsLogSheet = true
            } label: {
                Label("Log a session", systemImage: "checkmark.circle")
            }

            Button {
                thread.isMuted.toggle()
                CoreDataStack.shared.save()
                tpToast(thread.isMuted ? "Thread muted" : "Thread unmuted", tone: .neutral, symbol: "bell.slash")
            } label: {
                Label(thread.isMuted ? "Unmute" : "Mute", systemImage: thread.isMuted ? "bell" : "bell.slash")
            }

            Button(role: .destructive) {
                if let peer {
                    ReportPresenter.shared.present(.conversation(thread))
                    _ = peer
                }
            } label: {
                Label("Report or block", systemImage: "flag")
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

    // MARK: Bound note

    private var boundNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.tpEmber)

            Text("Sessions you log here are attached to the thread.")
                .font(TPFont.ui(11.5))
                .foregroundColor(.tpCreamFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.tpEmber.opacity(0.08))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.tpEmber.opacity(0.2), lineWidth: 1)
        )
        .padding(.bottom, 6)
    }

    private func daySeparator(_ date: Date?) -> some View {
        HStack(spacing: 10) {
            TPFadeRule()
            Text.tpLabel(TPTime.dayHeading(from: date), size: 9.5, tracking: 1.4)
            TPFadeRule()
        }
        .padding(.vertical, 8)
    }

    // MARK: Composer

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button(action: {
                TPHaptic.tap()
                showsLogSheet = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color.tpInkRaised)
                        .frame(width: 44, height: 44)
                    Circle()
                        .strokeBorder(Color.tpLine, lineWidth: 1)
                        .frame(width: 44, height: 44)
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.tpEmber)
                }
            }
            .buttonStyle(.plain)

            ZStack(alignment: .topLeading) {
                if draft.isEmpty {
                    Text("Say something useful…")
                        .font(TPFont.ui(14.5))
                        .foregroundColor(.tpCreamFaint)
                        .padding(.top, 12)
                        .padding(.leading, 5)
                }

                TextField("", text: $draft)
                    .font(TPFont.ui(14.5))
                    .foregroundColor(.tpCream)
                    .focused($composerFocused)
                    .tint(.tpEmber)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 12)
            }
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.tpInkRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(composerFocused ? Color.tpEmber.opacity(0.5) : Color.tpLine, lineWidth: 1)
            )

            Button(action: send) {
                ZStack {
                    Circle()
                        .fill(canSend ? AnyShapeStyle(TPGradient.ember) : AnyShapeStyle(Color.tpInkWell))
                        .frame(width: 44, height: 44)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(canSend ? .tpInk : .tpCreamFaint)
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .animation(TPMotion.snappy, value: canSend)
        }
        .padding(.horizontal, TPMetric.gutter)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
                TPBarFill(edge: .bottom)
                .overlay(alignment: .top) { TPFadeRule() }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Actions

    private func send() {
        guard canSend else { return }
        let text = draft
        draft = ""
        CommunityService.sendMessage(text, in: thread)
        TPHaptic.tap()
        reload()
    }

    private func startCall() {
        guard let peer else { return }
        caller.start(with: peer, in: thread)
    }

    private func openProfile() {
        guard let peer, let id = peer.id else { return }
        router.push(.profile(id))
    }

    private func reload() {
        messages = thread.sortedMessages
    }
}

// MARK: - Message row

struct MessageRow: View {

    let message: CDMessage
    var accent: Color = .tpEmber

    var body: some View {
        switch message.kind {
        case .text:
            textBubble
        case .checkIn:
            checkInCard
        case .gift:
            giftCard
        case .callDeclined, .callInvite:
            callLine
        }
    }

    // MARK: Text

    private var textBubble: some View {
        HStack {
            if message.isMine { Spacer(minLength: 54) }

            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                Text(message.body)
                    .font(TPFont.ui(14.5))
                    .foregroundColor(message.isMine ? .tpOnAccent : .tpCream)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) {
                    Text(message.timeLabel)
                        .font(TPFont.ui(10))
                        .foregroundColor(message.isMine ? Color.white.opacity(0.78) : .tpCreamFaint)

                    if message.isMine {
                        Image(systemName: message.status == .read ? "checkmark.circle.fill" : "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.70))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Group {
                    if message.isMine {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(TPGradient.accent(accent))
                    } else {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.tpInkRaised)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Color.tpLine, lineWidth: 1)
                            )
                    }
                }
            )

            if !message.isMine { Spacer(minLength: 54) }
        }
    }

    // MARK: Check in

    private var checkInCard: some View {
        HStack {
            if message.isMine { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.tpMint.opacity(0.18))
                            .frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.tpMint)
                    }

                    Text.tpLabel("Session logged", size: 9.5, tracking: 1.4, color: .tpMint)
                }

                Text(message.body)
                    .font(TPFont.display(17, .bold))
                    .foregroundColor(.tpCream)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message.timeLabel)
                    .font(TPFont.ui(10))
                    .foregroundColor(.tpCreamFaint)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.tpMint.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.tpMint.opacity(0.3), lineWidth: 1)
            )

            if !message.isMine { Spacer(minLength: 40) }
        }
    }

    // MARK: Gift

    private var giftCard: some View {
        let gift = TPGiftCatalog.gift(for: message.body.lowercased()) ?? TPGiftCatalog.all[0]

        return HStack {
            if message.isMine { Spacer(minLength: 40) }

            HStack(spacing: 12) {
                TPGiftToken(gift: gift, size: 42, showsPrice: false)

                VStack(alignment: .leading, spacing: 3) {
                    Text(message.isMine ? "You sent" : "They sent")
                        .font(TPFont.ui(11))
                        .foregroundColor(.tpCreamFaint)

                    Text(gift.name)
                        .font(TPFont.display(17, .bold))
                        .foregroundColor(.tpCream)
                }

                Spacer(minLength: 0)
            }
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(gift.accent.opacity(0.11))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(gift.accent.opacity(0.34), lineWidth: 1)
            )

            if !message.isMine { Spacer(minLength: 40) }
        }
    }

    // MARK: Call

    private var callLine: some View {
        HStack(spacing: 7) {
            Image(systemName: "phone.down.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.tpDanger)

            Text(message.body)
                .font(TPFont.ui(12))
                .foregroundColor(.tpCreamDim)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .padding(.vertical, 4)
    }
}

// MARK: - Log to thread
//
// The differentiator made concrete: pick a circle, log it, and the session
// lands in the conversation as a card both people can see.

struct LogToThreadSheet: View {

    let thread: CDConversation
    let onLogged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var habits: [CDHabit] = []
    @State private var detail = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Log a session")
                    .font(TPFont.display(24, .bold))
                    .foregroundColor(.tpCream)

                Text("It appears in the thread as a card, so \(thread.peer?.name ?? "they") can see what you actually did.")
                    .font(TPFont.ui(13))
                    .foregroundColor(.tpCreamDim)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if habits.isEmpty {
                Text("Join a circle first — sessions are logged against one.")
                    .font(TPFont.ui(14))
                    .foregroundColor(.tpCreamFaint)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 9) {
                    ForEach(habits, id: \.objectID) { habit in
                        Button {
                            log(habit)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(habit.accent.opacity(0.16))
                                        .frame(width: 40, height: 40)
                                    TPIcon(name: habit.iconAssetName, fallbackSymbol: habit.symbol, size: 19, tint: habit.accent)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(habit.title)
                                        .font(TPFont.ui(15, .semibold))
                                        .foregroundColor(.tpCream)
                                    Text(habit.cadenceLabel)
                                        .font(TPFont.ui(11.5))
                                        .foregroundColor(.tpCreamFaint)
                                }

                                Spacer(minLength: 8)

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(habit.accent)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.tpInkRaised)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.tpLine, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, TPMetric.gutter)
        .padding(.top, 12)
        .padding(.bottom, 30)
        .onAppear {
            habits = CoreDataStack.shared.fetch(
                CDHabit.self,
                predicate: NSPredicate(format: "isJoined == YES"),
                sortBy: [TPSort.byName]
            )
        }
    }

    private func log(_ habit: CDHabit) {
        HabitService.quickLog(habit)
        RefreshSignal.shared.bumpPractice()

        CommunityService.logCheckIn(
            habitName: habit.title,
            detail: "session logged",
            in: thread
        )

        TPHaptic.success()
        tpToast("Logged and shared", tone: .success, symbol: "checkmark")
        dismiss()
        onLogged()
    }
}
