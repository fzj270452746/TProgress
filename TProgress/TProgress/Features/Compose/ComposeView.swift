import SwiftUI
import CoreData
import PhotosUI

// MARK: - Compose

/// One selectable circle, with "None" folded in as a nil id so the whole set
/// packs into a single flow.
private struct TagOption: Hashable {

    let id: UUID?
    let title: String
    let symbol: String?
    let assetName: String?
}

struct ComposeView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared

    @State private var kind: PostKind = .progress
    @State private var text = ""
    @State private var amount = ""
    @State private var unit = "pages"
    @State private var minutes = ""
    @State private var media: [PendingMedia] = []
    @State private var selectedHabitID: UUID?
    @State private var isPickingImages = false
    @State private var isPickingVideo = false
    @State private var isPublishing = false
    @State private var legalDocument: LegalDocument?
    @State private var showDiscard = false

    @State private var bodyFocused = false

    @Namespace private var segment

    private let units = ["pages", "min", "words", "km", "reps", "sessions"]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    kindSelector
                    bodyEditor
                    quantityLogger
                    mediaSection
                    circleSection
                    eulaBanner
                }
                .padding(.horizontal, TPMetric.gutter)
                .padding(.top, 4)
                .padding(.bottom, 118)
            }
            .tpDismissKeyboardOnTap()

            publishBar
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
        .sheet(isPresented: $isPickingImages) {
            TPMediaPicker(selectionLimit: max(1, 6 - media.count), filter: .images) { picked in
                isPickingImages = false
                guard !picked.isEmpty else { return }
                media.removeAll { $0.isVideo }
                media.append(contentsOf: picked.prefix(6 - media.count))
            } onCancel: {
                isPickingImages = false
            }
        }
        .sheet(isPresented: $isPickingVideo) {
            TPMediaPicker(selectionLimit: 1, filter: .videos) { picked in
                isPickingVideo = false
                guard !picked.isEmpty else { return }
                media = Array(picked.prefix(1))
            } onCancel: {
                isPickingVideo = false
            }
        }
        .sheet(item: $legalDocument) { document in
            LegalSheet(document: document)
        }
        .confirmationDialog(
            "Discard this post?",
            isPresented: $showDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                router.pop()
            }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Anything you have written will be lost.")
        }
        .onChange(of: session.isSignedIn) { isSignedIn in
            if !isSignedIn { router.pop() }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            TPIconButton(symbol: "xmark", size: 38) {
                if hasContent {
                    showDiscard = true
                } else {
                    router.pop()
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("New post")
                    .font(TPFont.display(22, .bold))
                    .foregroundColor(.tpCream)
                Text.tpLabel("Log it, then let it go", size: 9.5, tracking: 1.5)
            }

            Spacer(minLength: 8)

            if session.isSignedIn {
                TPAvatar(
                    seed: session.currentUser?.avatarSeed ?? 0,
                    name: session.currentUser?.name ?? "?",
                    size: 36,
                    imagePath: session.currentUser?.avatarAssetName
                )
            } else {
                Button {
                    session.presentAuth(prompt: "Sign in to publish.")
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Sign in")
                            .font(TPFont.ui(12.5, .semibold))
                    }
                    .foregroundColor(.tpEmber)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Capsule(style: .continuous).fill(Color.tpEmber.opacity(0.13)))
                    .overlay(Capsule(style: .continuous).strokeBorder(Color.tpEmber.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, TPMetric.gutter)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: Kind

    private var kindSelector: some View {
        TPSegmented(
            items: PostKind.allCases,
            selection: $kind,
            title: \.label,
            namespace: segment
        )
    }

    // MARK: Body

    private var bodyEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text.tpLabel("What did you do?")
                Spacer()
                Text("\(text.count)/\(maxBodyLength)")
                    .font(TPFont.figure(11, .semibold))
                    .foregroundColor(text.count >= maxBodyLength ? .tpBloom : .tpCreamFaint)
            }

            TPTextEditor(
                text: $text,
                placeholder: placeholder,
                height: 150,
                fontSize: 15,
                maxLength: maxBodyLength,
                onFocusChange: { bodyFocused = $0 }
            )
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.tpInkRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(bodyFocused ? Color.tpEmber.opacity(0.5) : Color.tpLine, lineWidth: 1)
            )
        }
        .animation(TPMotion.snappy, value: bodyFocused)
    }

    private var maxBodyLength: Int { 600 }

    private var placeholder: String {
        switch kind {
        case .progress: return "Read 5 pages of… Practised the same four bars…"
        case .checkIn:  return "Showed up for twelve minutes. Nothing clever."
        case .summary:  return "Thirty days. Eight thousand words. Two of them good."
        }
    }

    // MARK: Quantity

    private var quantityLogger: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text.tpLabel("How much?")

            HStack(spacing: 10) {
                numberField(label: "Amount", text: $amount, keyboard: .decimalPad)
                numberField(label: "Minutes", text: $minutes, keyboard: .numberPad)
                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(units, id: \.self) { candidate in
                        TPSelectableChip(
                            text: candidate,
                            isSelected: unit == candidate
                        ) {
                            unit = candidate
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    /// "None" plus every circle in the community, joined ones first. The count
    /// in the section header is taken from this, so it can never drift from
    /// what the row actually holds.
    private var tagOptions: [TagOption] {
        [TagOption(id: nil, title: "None", symbol: "slash.circle", assetName: nil)]
            + taggableHabits.map {
                TagOption(
                    id: $0.id,
                    title: $0.title,
                    symbol: $0.symbol,
                    assetName: $0.iconAssetName
                )
            }
    }

    private func numberField(
        label: String,
        text: Binding<String>,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text.tpLabel(label, size: 9.5, tracking: 1.3)

            TextField("0", text: text)
                .keyboardType(keyboard)
                .font(TPFont.figure(24, .bold))
                .foregroundColor(.tpCream)
                .tint(.tpEmber)
                .frame(height: 38)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .frame(width: 118, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
    }

    // MARK: Media

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text.tpLabel("Attach")
                Spacer()
                Text("\(media.count)/6 · one video max")
                    .font(TPFont.ui(11))
                    .foregroundColor(.tpCreamFaint)
            }

            if !media.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(media) { item in
                            mediaThumb(item)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            HStack(spacing: 10) {
                attachButton(
                    symbol: "photo.on.rectangle",
                    title: "Photos",
                    enabled: media.count < 6 && !media.contains { $0.isVideo }
                ) {
                    isPickingImages = true
                }

                attachButton(
                    symbol: "video.badge.plus",
                    title: "Video",
                    enabled: media.isEmpty
                ) {
                    isPickingVideo = true
                }
            }
        }
    }

    private func mediaThumb(_ item: PendingMedia) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = item.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    TPArt(seed: Int64(item.path.hashValue % 4000), cornerRadius: 15)
                }
            }
            .frame(width: 92, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            if item.isVideo {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            Button {
                TPHaptic.tap()
                TPMediaLibrary.remove(path: item.path)
                withAnimation(TPMotion.snappy) {
                    media.removeAll { $0.id == item.id }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.tpInk)
                    .background(Circle().fill(Color.tpCream).frame(width: 15, height: 15))
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
        }
        .frame(width: 92, height: 92)
    }

    private func attachButton(
        symbol: String,
        title: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            guard enabled else { return }
            TPHaptic.tap()
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(TPFont.ui(13.5, .semibold))
            }
            .foregroundColor(enabled ? .tpCream : .tpCreamFaint)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.tpInkRaised)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.tpLine, lineWidth: 1)
            )
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
    }

    // MARK: Circles

    private var circleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                Text.tpLabel("Tag a circle")
                Spacer()
                // Naming the size of the row matters more than it looks: a
                // scroller that ends two chips past the screen edge reads as a
                // short list, and the count is what tells you it is not.
                Text(tagOptions.count == 1 ? "1 circle" : "\(tagOptions.count) circles")
                    .font(TPFont.ui(11))
                    .foregroundColor(.tpCreamFaint)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tagOptions, id: \.self) { option in
                        TPSelectableChip(
                            text: option.title,
                            isSelected: selectedHabitID == option.id,
                            symbol: option.symbol,
                            assetName: option.assetName
                        ) {
                            selectedHabitID = option.id
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Text("Your circles come first.")
                .font(TPFont.ui(11))
                .foregroundColor(.tpCreamFaint)
        }
    }

    // MARK: EULA

    private var eulaBanner: some View {
        Button {
            legalDocument = .eula
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.tpEmber.opacity(0.16))
                        .frame(width: 36, height: 36)

                    Image(systemName: "doc.text")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.tpEmber)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Publishing means you accept the EULA")
                        .font(TPFont.ui(14, .semibold))
                        .foregroundColor(.tpCream)

                    Text("Tap to read the End User Licence Agreement, plus the Terms of Service and Privacy Policy that apply to everything you post.")
                        .font(TPFont.ui(12.5))
                        .foregroundColor(.tpCreamDim)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.tpEmber)
                    .padding(.top, 10)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.tpEmber.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.tpEmber.opacity(0.34), lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Publish

    private var publishBar: some View {
        VStack(spacing: 0) {
            TPFadeRule()

            TPPrimaryButton(
                title: "Publish",
                symbol: "paperplane.fill",
                isLoading: isPublishing,
                isEnabled: canPublish
            ) {
                publish()
            }
            .padding(.horizontal, TPMetric.gutter)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .background(
            TPBarFill(edge: .bottom)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: Data

    /// Every circle is taggable, not only the ones already joined. Offering just
    /// the joined set made the row read as a fixed group of four and hid the
    /// rest of the community from the one screen where you would go looking for
    /// it. Joined circles sort first, so the common case is still the shortest
    /// reach.
    private var taggableHabits: [CDHabit] {
        CoreDataStack.shared.fetch(
            CDHabit.self,
            sortBy: [TPSort.byName]
        )
        .sorted { lhs, rhs in
            if lhs.isJoined != rhs.isJoined { return lhs.isJoined }
            return lhs.title < rhs.title
        }
    }

    private var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !media.isEmpty
    }

    private var canPublish: Bool {
        guard session.isSignedIn, !isPublishing else { return false }
        let hasText = text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 1
        return hasText || !media.isEmpty
    }

    // MARK: Actions

    private func publish() {
        guard canPublish else { return }
        bodyFocused = false
        TPKeyboard.dismiss()
        isPublishing = true

        let body = text
        let chosenKind = kind
        let chosenUnit = unit
        let chosenAmount = Double(amount) ?? 0
        let chosenMinutes = Int(minutes) ?? 0
        let chosenMedia = media
        let habit = taggableHabits.first { $0.id == selectedHabitID }

        Task {
            await TPLoadingRun.run(minimumDuration: 1.0, message: "Publishing") {
                let created = CommunityService.createPost(
                    text: body,
                    kind: chosenKind,
                    topic: habit?.category?.lowercased(),
                    habitName: habit?.title,
                    amount: chosenAmount,
                    unit: chosenUnit,
                    minutes: chosenMinutes,
                    media: chosenMedia,
                    taggedHabitID: habit?.id
                )

                isPublishing = false

                guard created != nil else {
                    tpToast("Nothing to publish yet.", tone: .warning, symbol: "exclamationmark")
                    return
                }

                TPHaptic.success()
                RefreshSignal.shared.bumpFeed()
                router.pop()
                router.tab = .today
                tpToast("Published", tone: .success, symbol: "paperplane.fill")
            }
        }
    }
}
