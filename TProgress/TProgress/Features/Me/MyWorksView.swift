import SwiftUI
import CoreData

// MARK: - My works

struct MyWorksView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var posts: [CDPost] = []
    @State private var pendingDelete: CDPost?

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "My works",
                subtitle: "\(posts.count) published",
                onBack: { router.pop() }
            )

            ScrollView {
                VStack(spacing: 12) {
                    if posts.isEmpty {
                        TPEmptyState(
                            symbol: "square.stack",
                            title: "Nothing published yet",
                            message: "Log the first thing you finished today. It does not have to be impressive — it has to be true.",
                            actionTitle: "Write a post",
                            action: {
                                router.pop()
                                router.push(.compose)
                            },
                            accent: .tpLilac
                        )
                    } else {
                        ForEach(posts, id: \.objectID) { post in
                            CompactPostRow(post: post, showsAuthor: false, trailing: AnyView(deleteButton(post))) {
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
        .confirmationDialog(
            "Delete this post?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let post = pendingDelete {
                    CommunityService.delete(post: post)
                    RefreshSignal.shared.bumpFeed()
                    tpToast("Post removed", tone: .success, symbol: "trash")
                    withAnimation(TPMotion.gentle) { reload() }
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("The post and its replies are removed from your shelf.")
        }
    }

    private func deleteButton(_ post: CDPost) -> some View {
        Button {
            TPHaptic.tap()
            pendingDelete = post
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.tpDanger)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.tpBloom.opacity(0.12)))
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
            predicate: NSPredicate(format: "isMine == YES"),
            sortBy: [TPSort.newestPost]
        )
    }
}
