import SwiftUI
import CoreData

// MARK: - My following

struct MyFollowingView: View {

    @ObservedObject private var router = Router.shared

    @State private var people: [CDUser] = []

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "Following",
                subtitle: "\(people.count) people",
                onBack: { router.pop() }
            )

            ScrollView {
                VStack(spacing: 10) {
                    if people.isEmpty {
                        TPEmptyState(
                            symbol: "person.2",
                            title: "Not following anyone",
                            message: "Follow the people whose streaks you want to see in your feed.",
                            accent: .tpMint
                        )
                    } else {
                        ForEach(people, id: \.objectID) { person in
                            row(person)
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
    }

    private func row(_ person: CDUser) -> some View {
        HStack(spacing: 12) {
            Button {
                open(person)
            } label: {
                HStack(spacing: 12) {
                    TPAvatar(
                        seed: person.avatarSeed,
                        name: person.name,
                        size: 48,
                        imagePath: person.avatarAssetName
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(person.name)
                            .font(TPFont.ui(15, .semibold))
                            .foregroundColor(.tpCream)

                        Text(person.bioText)
                            .font(TPFont.ui(12))
                            .foregroundColor(.tpCreamFaint)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button {
                CommunityService.toggleFollow(person)
                TPHaptic.tap()
                tpToast("Unfollowed \(person.name)", tone: .neutral, symbol: "person.badge.minus")
                withAnimation(TPMotion.gentle) { reload() }
            } label: {
                Text("Unfollow")
                    .font(TPFont.ui(12.5, .semibold))
                    .foregroundColor(.tpCreamDim)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.tpInkWell))
                    .overlay(Capsule().strokeBorder(Color.tpLine, lineWidth: 1))
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

    private func open(_ person: CDUser) {
        guard let id = person.id else { return }
        router.push(.profile(id))
    }

    private func reload() {
        people = CommunityService.following()
    }
}
