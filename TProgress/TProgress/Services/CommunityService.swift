import Foundation
import CoreData
import SwiftUI

// MARK: - Reports

enum ReportReason: String, CaseIterable, Identifiable {

    case illegal
    case inappropriate
    case spam
    case blockUser
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .illegal:         return "Illegal content"
        case .inappropriate:   return "Inappropriate content"
        case .spam:            return "Spam or scam"
        case .blockUser:       return "Block this user"
        case .other:           return "Something else"
        }
    }

    var detail: String {
        switch self {
        case .illegal:         return "Content that breaks the law or promotes harm."
        case .inappropriate:   return "Content that does not belong in a progress feed."
        case .spam:            return "Repetitive, misleading or commercial posting."
        case .blockUser:       return "Removes them and everything they posted, from your view."
        case .other:           return "Tell us in your own words."
        }
    }

    var symbol: String {
        switch self {
        case .illegal:         return "exclamationmark.shield"
        case .inappropriate:   return "eye.slash"
        case .spam:            return "hand.raised"
        case .blockUser:       return "person.crop.circle.badge.xmark"
        case .other:           return "ellipsis.bubble"
        }
    }

    /// Destructive choices read in bloom rather than ember.
    var isDestructive: Bool {
        self == .blockUser || self == .illegal
    }
}

enum ReportTarget {
    case post(CDPost)
    case comment(CDComment)
    case user(CDUser)
    case conversation(CDConversation)

    var subjectName: String {
        switch self {
        case .post(let post):           return post.author?.name ?? "this post"
        case .comment(let comment):     return comment.author?.name ?? "this reply"
        case .user(let user):           return user.name
        case .conversation(let thread): return thread.peer?.name ?? "this conversation"
        }
    }
}

/// What the caller should do once a report is filed.
enum ReportOutcome {
    case stay            // comment removed, page unaffected
    case leaveAndRefresh // post or user removed, go back to the source tab
}

// MARK: - Community

/// Every mutation that touches the shared community graph. Views call these and
/// re-render from Core Data rather than keeping their own copies.
enum CommunityService {

    private static var context: NSManagedObjectContext { CoreDataStack.shared.context }

    // MARK: Likes

    static func toggleLike(_ post: CDPost) {
        post.isLikedByMe.toggle()
        post.likeCount = max(0, post.likeCount + (post.isLikedByMe ? 1 : -1))
        CoreDataStack.shared.save()
    }

    static func toggleCommentLike(_ comment: CDComment) {
        comment.isLikedByMe.toggle()
        comment.likeCount = max(0, comment.likeCount + (comment.isLikedByMe ? 1 : -1))
        CoreDataStack.shared.save()
    }

    // MARK: Comments

    @discardableResult
    static func addComment(to post: CDPost, text: String) -> CDComment? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let me = AppSession.shared.currentUser else { return nil }

        let comment = CDComment(context: context)
        comment.id = UUID()
        comment.text = trimmed
        comment.createdAt = Date()
        comment.likeCount = 0
        comment.isLikedByMe = false
        comment.isMine = true
        comment.post = post
        comment.author = me

        CoreDataStack.shared.save()
        return comment
    }

    static func delete(comment: CDComment) {
        guard let post = comment.post else {
            CoreDataStack.shared.delete(comment)
            return
        }
        context.delete(comment)
        post.likeCount = post.likeCount // touch to keep the object alive
        CoreDataStack.shared.save()
    }

    // MARK: Posts

    @discardableResult
    static func createPost(
        text: String,
        kind: PostKind,
        topic: String?,
        habitName: String?,
        amount: Double,
        unit: String,
        minutes: Int,
        media: [PendingMedia],
        taggedHabitID: UUID?
    ) -> CDPost? {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty || !media.isEmpty, let me = AppSession.shared.currentUser else { return nil }

        let post = CDPost(context: context)
        post.id = UUID()
        post.text = body
        post.author = me
        post.createdAt = Date()
        post.kind = kind
        post.topicTag = topic
        post.habitName = habitName
        post.amountValue = amount
        post.amountUnit = unit
        post.durationMinutes = Int32(minutes)
        post.likeCount = 0
        post.giftCount = 0
        post.isLikedByMe = false
        post.isMine = true
        post.seed = Int64.random(in: 1...9_000)

        // The tag used to be a name dropped into a string field and never read
        // back. Pointing it at the circle is what lets a circle list its own
        // posts and what the backfill repairs for existing ones.
        if let taggedHabitID {
            post.habit = TPStore.habit(taggedHabitID)
        }

        for (index, item) in media.enumerated() {
            let entry = CDMedia(context: context)
            entry.id = UUID()
            entry.order = Int32(index)
            entry.kind = item.isVideo ? .video : .image
            entry.assetName = item.path
            entry.durationSeconds = item.duration
            entry.seed = post.seed &+ Int64(index) &* 17
            entry.post = post
        }

        // `totalCheckIns` now counts real check-ins, maintained by HabitService.
        // Publishing a post is a different act from logging a day, and adding
        // one here would double-count every check-in shared to a profile.
        CoreDataStack.shared.save()
        return post
    }

    static func delete(post: CDPost) {
        context.delete(post)
        CoreDataStack.shared.save()
    }

    // MARK: Gifts

    static func sendGift(_ gift: TPGift, to post: CDPost, amountCents: Int) {
        let event = CDGiftEvent(context: context)
        event.id = UUID()
        event.giftKey = gift.key
        event.productID = gift.productID
        event.priceCents = Int32(amountCents)
        event.createdAt = Date()
        event.post = post
        event.sender = AppSession.shared.currentUser

        post.giftCount += 1

        // Gifts land in the thread too, so the token has somewhere to live.
        if let peer = post.author,
           peer.isFriend,
           let conversation = conversation(with: peer) {
            let message = CDMessage(context: context)
            message.id = UUID()
            message.kind = .gift
            message.text = gift.name
            message.isMine = true
            message.status = .sent
            message.createdAt = Date()
            message.conversation = conversation
            conversation.lastMessageAt = message.createdAt
            conversation.lastMessageText = "Sent a \(gift.name)"
        }

        CoreDataStack.shared.save()
    }

    // MARK: Following

    static func toggleFollow(_ user: CDUser) {
        guard user.isCurrentUser == false else { return }
        user.isFollowedByMe.toggle()
        CoreDataStack.shared.save()
    }

    static func following() -> [CDUser] {
        CoreDataStack.shared.fetch(
            CDUser.self,
            predicate: NSPredicate(format: "isFollowedByMe == YES AND isCurrentUser == NO"),
            sortBy: [TPSort.byDisplayName]
        )
    }

    /// The accounts that follow the signed-in user. There was no way to see
    /// these before — `MyFollowingView` listed the other direction only, and the
    /// follower number on a profile was derived from a seed.
    static func followers(of user: CDUser? = nil) -> [CDUser] {
        let me = user ?? AppSession.shared.currentUser
        guard let me, me.isCurrentUser else { return [] }

        return CoreDataStack.shared.fetch(
            CDUser.self,
            predicate: NSPredicate(format: "followsMe == YES AND isCurrentUser == NO AND isBlocked == NO"),
            sortBy: [TPSort.byDisplayName]
        )
    }

    /// Follows back in one tap, which is the only sensible action on that list.
    static func followBack(_ user: CDUser) {
        guard !user.isFollowedByMe else { return }
        user.isFollowedByMe = true
        CoreDataStack.shared.save()
    }

    // MARK: Circles

    /// Posts tagged to a circle, newest first.
    static func posts(in habit: CDHabit, limit: Int = 20) -> [CDPost] {
        habit.posts
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }

    /// What a circle has been up to, posts and check-ins merged into one
    /// timeline. Check-ins carry no author of their own, so only the account's
    /// are shown — the seeded log belongs to everybody in the circle and cannot
    /// honestly be attributed to a person.
    struct Moment: Identifiable {
        enum Kind {
            case post(CDPost)
            case checkIn(CDCheckIn)
        }

        let id: UUID
        let date: Date
        let kind: Kind
    }

    static func moments(in habit: CDHabit, limit: Int = 12) -> [Moment] {
        var moments: [Moment] = []

        for post in habit.posts {
            moments.append(Moment(id: post.id ?? UUID(), date: post.createdAt ?? .distantPast, kind: .post(post)))
        }

        for entry in habit.checkIns where entry.isMine {
            moments.append(
                Moment(id: entry.id ?? UUID(), date: entry.date ?? .distantPast, kind: .checkIn(entry))
            )
        }

        return moments
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: Friendship

    static func sendFriendRequest(to user: CDUser) {
        guard user.friendState == .none else { return }
        user.friendState = .requested
        CoreDataStack.shared.save()
    }

    static func acceptFriendRequest(from user: CDUser) {
        guard user.friendState == .incoming || user.friendState == .requested else { return }
        user.friendState = .friends
        user.isFollowedByMe = true
        user.followsMe = true
        CoreDataStack.shared.save()
        ensureConversation(with: user)
    }

    static func declineFriendRequest(from user: CDUser) {
        guard user.friendState == .incoming else { return }
        user.friendState = .none
        CoreDataStack.shared.save()
    }

    static func removeFriend(_ user: CDUser) {
        user.friendState = .none
        CoreDataStack.shared.save()
    }

    static func friends() -> [CDUser] {
        CoreDataStack.shared.fetch(
            CDUser.self,
            predicate: NSPredicate(format: "friendStateRaw == %@", FriendState.friends.rawValue),
            sortBy: [TPSort.byDisplayName]
        )
    }

    /// People the signed-in user could add — never a random stranger feed,
    /// just the accounts that already exist in this community.
    static func suggestedPeople(limit: Int = 8) -> [CDUser] {
        let all = CoreDataStack.shared.fetch(
            CDUser.self,
            predicate: NSPredicate(format: "isCurrentUser == NO AND isBlocked == NO AND friendStateRaw != %@",
                                   FriendState.friends.rawValue),
            sortBy: [NSSortDescriptor(key: "followsMe", ascending: false), TPSort.byDisplayName]
        )
        return Array(all.prefix(limit))
    }

    // MARK: Conversations

    @discardableResult
    static func ensureConversation(with peer: CDUser) -> CDConversation {
        if let existing = conversation(with: peer) { return existing }

        let thread = CDConversation(context: context)
        thread.id = UUID()
        thread.peer = peer
        thread.unreadCount = 0
        thread.isMuted = false
        thread.lastMessageAt = Date()
        thread.lastMessageText = ""
        CoreDataStack.shared.save()
        return thread
    }

    static func conversation(with peer: CDUser) -> CDConversation? {
        CoreDataStack.shared.fetch(CDConversation.self).first {
            $0.peer?.objectID == peer.objectID
        }
    }

    static func conversations() -> [CDConversation] {
        CoreDataStack.shared.fetch(
            CDConversation.self,
            sortBy: [TPSort.newestMessage]
        ).filter { $0.peer?.friendState == .friends }
    }

    static func sendMessage(_ text: String, in thread: CDConversation) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let message = CDMessage(context: context)
        message.id = UUID()
        message.text = trimmed
        message.isMine = true
        message.kind = .text
        message.status = .sent
        message.createdAt = Date()
        message.conversation = thread

        thread.lastMessageAt = message.createdAt
        thread.lastMessageText = trimmed
        CoreDataStack.shared.save()
    }

    static func markRead(_ thread: CDConversation) {
        guard thread.unreadCount != 0 else { return }
        thread.unreadCount = 0
        CoreDataStack.shared.save()
    }

    static func logCheckIn(
        habitName: String,
        detail: String,
        in thread: CDConversation
    ) {
        let message = CDMessage(context: context)
        message.id = UUID()
        message.text = "\(habitName) · \(detail)"
        message.isMine = true
        message.kind = .checkIn
        message.status = .sent
        message.createdAt = Date()
        message.conversation = thread

        thread.lastMessageAt = message.createdAt
        thread.lastMessageText = "Logged \(habitName)"
        CoreDataStack.shared.save()
    }

    /// Records a declined video call in the thread so the attempt leaves a trace.
    static func logMissedCall(in thread: CDConversation) {
        let message = CDMessage(context: context)
        message.id = UUID()
        message.kind = .callDeclined
        message.text = "Video call declined"
        message.isMine = true
        message.status = .sent
        message.createdAt = Date()
        message.conversation = thread

        thread.lastMessageAt = message.createdAt
        thread.lastMessageText = "Video call declined"
        CoreDataStack.shared.save()
    }

    // MARK: Reporting

    @discardableResult
    static func fileReport(
        target: ReportTarget,
        reason: ReportReason,
        note: String
    ) -> ReportOutcome {
        let author: CDUser?

        switch target {
        case .post(let post):
            author = post.author
        case .comment(let comment):
            author = comment.author
        case .user(let user):
            author = user
        case .conversation(let thread):
            author = thread.peer
        }

        // A report always removes the object it points at.
        switch target {
        case .post(let post):
            delete(post: post)
            if reason == .blockUser, let author { block(author) }
            return .leaveAndRefresh

        case .comment(let comment):
            delete(comment: comment)
            return .stay

        case .user, .conversation:
            if let author { block(author) }
            return .leaveAndRefresh
        }
    }

    /// Blocking hides the person and every trace of them locally.
    static func block(_ user: CDUser) {
        guard !user.isCurrentUser else { return }

        user.isBlocked = true
        user.friendState = .none
        user.isFollowedByMe = false

        for post in user.posts {
            context.delete(post)
        }

        if let thread = conversation(with: user) {
            context.delete(thread)
        }

        CoreDataStack.shared.save()
    }

    // MARK: Erase

    /// Removes a person and everything they authored. Used by account deletion
    /// and by reporting a user from their profile.
    static func erase(user: CDUser) {
        for post in user.posts {
            context.delete(post)
        }
        for comment in user.comments {
            context.delete(comment)
        }
        if let thread = conversation(with: user) {
            context.delete(thread)
        }
        context.delete(user)
        CoreDataStack.shared.save()
    }
}

// MARK: - Draft media

/// A picked asset on its way into a post.
struct PendingMedia: Identifiable, Equatable {

    let id = UUID()
    var path: String
    var isVideo: Bool
    var duration: Double
    var thumbnail: UIImage?

    static func == (lhs: PendingMedia, rhs: PendingMedia) -> Bool { lhs.id == rhs.id }
}
