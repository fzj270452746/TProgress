import SwiftUI
import CoreData

// MARK: - My likes

struct MyLikesView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var posts: [CDPost] = []

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "Liked posts",
                subtitle: "\(posts.count) saved",
                onBack: { router.pop() }
            )

            ScrollView {
                VStack(spacing: 12) {
                    if posts.isEmpty {
                        TPEmptyState(
                            symbol: "heart",
                            title: "Nothing liked yet",
                            message: "When a post makes you want to keep going, tap the heart and it will wait for you here.",
                            accent: .tpBloom
                        )
                    } else {
                        ForEach(posts, id: \.objectID) { post in
                            CompactPostRow(post: post, trailing: AnyView(unlessButton(post))) {
                                open(post)
                            }
                        }
                    }
                }
                .padding(.horizontal, TPMetric.gutter)
                .padding(.bottom, 44)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tpBackdrop(.deep)
        .onAppear(perform: reload)
        .onChange(of: refresh.feed) { _ in reload() }
    }

    private func unlessButton(_ post: CDPost) -> some View {
        Button {
            CommunityService.toggleLike(post)
            TPHaptic.tap()
            tpToast("Removed from likes", tone: .neutral, symbol: "heart.slash")
            withAnimation(TPMotion.gentle) { reload() }
        } label: {
            Image(systemName: "heart.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.tpDanger)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.tpBloom.opacity(0.13)))
        }
        .buttonStyle(.plain)
    }

    private func open(_ post: CDPost) {
        guard let id = post.id else { return }
        router.push(.post(id))
    }

    private func reload() {
        posts = CoreDataStack.shared.fetch(
            CDPost.self,
            predicate: NSPredicate(format: "isLikedByMe == YES"),
            sortBy: [TPSort.newestPost]
        )
    }
}
