import SwiftUI
import CoreData

// MARK: - Followers
//
// The other half of the graph. The profile card has always shown a follower
// number — it was derived from the account's seed and led nowhere, because
// there was no list behind it. This is that list.

struct MyFollowersView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var people: [CDUser] = []

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "Followers",
                subtitle: people.isEmpty ? nil : "\(people.count) \(people.count == 1 ? "person" : "people")",
                onBack: { router.pop() }
            )

            ScrollView {
                VStack(spacing: 10) {
                    if people.isEmpty {
                        TPEmptyState(
                            symbol: "person.2",
                            title: "No followers yet",
                            message: "Publish a recap and the people in your circles will find it.",
                            accent: .tpLilac
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
        .onChange(of: refresh.profile) { _ in reload() }
    }

    // MARK: Row

    private func row(_ person: CDUser) -> some View {
        HStack(spacing: 12) {
            Button {
                guard let id = person.id else { return }
                router.push(.profile(id))
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
                            .lineLimit(1)

                        Text(person.bioText)
                            .font(TPFont.ui(12))
                            .foregroundColor(.tpCreamFaint)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            followBackButton(person)
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

    @ViewBuilder
    private func followBackButton(_ person: CDUser) -> some View {
        if person.isFollowedByMe {
            Text("Following")
                .font(TPFont.ui(12.5, .semibold))
                .foregroundColor(.tpCreamFaint)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous).fill(Color.tpInkWell)
                )
        } else {
            Button {
                CommunityService.followBack(person)
                TPHaptic.tap()
                tpToast("Following \(person.name)", tone: .success, symbol: "person.badge.plus")
                RefreshSignal.shared.bumpFeed()
                reload()
            } label: {
                Text("Follow back")
                    .font(TPFont.ui(12.5, .bold))
                    .foregroundColor(.tpOnAccent)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(TPGradient.accent(.tpLilac))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func reload() {
        people = CommunityService.followers()
    }
}
