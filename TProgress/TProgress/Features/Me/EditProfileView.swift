import SwiftUI
import PhotosUI

// MARK: - Edit profile

struct EditProfileView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared

    @State private var displayName = ""
    @State private var bio = ""
    @State private var isPickingPhoto = false
    @State private var isSaving = false
    @State private var bioFocused = false

    @FocusState private var focus: Field?

    private enum Field: Hashable { case name }

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: "Edit profile",
                subtitle: "Visible to everyone",
                onBack: { router.pop() }
            )

            ScrollView {
                VStack(spacing: 22) {
                    avatarBlock
                    fields
                    saveButton
                }
                .padding(.horizontal, TPMetric.gutter)
                .padding(.bottom, 44)
            }
            .tpDismissKeyboardOnTap()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                // A pushed page covers the tab root, so it paints its own ground. Kept
                // deeper than a tab's so forms and long reads stay comfortable.
                TPBackdropView(style: .deep)
                TPHalo(color: .tpEmber, spread: 1.05)
                    .offset(y: -230)
                TPGrain(opacity: 0.04)
            }
            .ignoresSafeArea()
        )
        .sheet(isPresented: $isPickingPhoto) {
            TPMediaPicker(selectionLimit: 1, filter: .images) { picked in
                isPickingPhoto = false
                guard let first = picked.first, let image = first.thumbnail else { return }
                if let path = TPMediaLibrary.saveImage(image) {
                    session.updateAvatar(path: path)
                    TPHaptic.success()
                    tpToast("Photo updated", tone: .success, symbol: "person.crop.circle")
                }
            } onCancel: {
                isPickingPhoto = false
            }
        }
        .onAppear(perform: load)
    }

    // MARK: Avatar

    private var avatarBlock: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                if let user = session.currentUser {
                    TPAvatar(
                        seed: user.avatarSeed,
                        name: displayName.isEmpty ? user.name : displayName,
                        size: 118,
                        showsRing: true,
                        ringColor: .tpEmber,
                        imagePath: user.avatarAssetName
                    )
                }

                ZStack {
                    Circle()
                        .fill(TPGradient.ember)
                        .frame(width: 38, height: 38)
                    Circle()
                        .strokeBorder(Color.tpInk, lineWidth: 3)
                        .frame(width: 38, height: 38)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.tpInk)
                }
                .offset(x: 4, y: 4)
            }
            .onTapGesture {
                TPHaptic.tap()
                isPickingPhoto = true
            }

            HStack(spacing: 10) {
                Button {
                    isPickingPhoto = true
                } label: {
                    actionLabel("Choose photo", symbol: "photo.on.rectangle")
                }
                .buttonStyle(.plain)

                Button {
                    session.shuffleAvatarPattern()
                    tpToast("New pattern", tone: .neutral, symbol: "sparkles")
                } label: {
                    actionLabel("Shuffle pattern", symbol: "sparkles")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
    }

    private func actionLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(TPFont.ui(13, .semibold))
        }
        .foregroundColor(.tpCream)
        .padding(.horizontal, 15)
        .frame(height: 40)
        .background(Capsule(style: .continuous).fill(Color.tpInkRaised))
        .overlay(Capsule(style: .continuous).strokeBorder(Color.tpLine, lineWidth: 1))
    }

    // MARK: Fields

    private var fields: some View {
        VStack(spacing: 22) {
            TPTextField(
                label: "Display name",
                placeholder: "How your name appears",
                text: $displayName,
                capitalization: .words,
                submitLabel: .next,
                symbol: "textformat",
                onSubmit: { focus = nil }
            )
            .focused($focus, equals: .name)

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text.tpLabel("Bio")
                    Spacer()
                    Text("\(bio.count)/160")
                        .font(TPFont.figure(11, .semibold))
                        .foregroundColor(bio.count > 160 ? .tpBloom : .tpCreamFaint)
                }

                TPTextEditor(
                    text: $bio,
                    placeholder: "One line about what you are keeping at.",
                    height: 118,
                    fontSize: 14.5,
                    maxLength: 160,
                    onFocusChange: { bioFocused = $0 }
                )
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.tpInkRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(bioFocused ? Color.tpEmber.opacity(0.5) : Color.tpLine, lineWidth: 1)
                )
            }

            if let username = session.currentUser?.username {
                HStack(spacing: 10) {
                    Image(systemName: "at")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.tpCreamFaint)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(username)
                            .font(TPFont.ui(14.5, .medium))
                            .foregroundColor(.tpCreamDim)
                        Text("Usernames are permanent.")
                            .font(TPFont.ui(11))
                            .foregroundColor(.tpCreamFaint)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.tpInkWell)
                )
            }
        }
    }

    // MARK: Save

    private var saveButton: some View {
        TPPrimaryButton(
            title: "Save changes",
            symbol: "checkmark",
            isLoading: isSaving,
            isEnabled: !trimmedName.isEmpty && bio.count <= 160
        ) {
            save()
        }
    }

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Actions

    private func load() {
        guard let user = session.currentUser else { return }
        displayName = user.name
        bio = user.bio ?? ""
    }

    private func save() {
        focus = nil
        TPKeyboard.dismiss()
        isSaving = true

        let name = trimmedName
        let about = bio

        Task {
            await TPLoadingRun.run(minimumDuration: 1.0, message: "Saving your profile") {
                session.updateProfile(displayName: name, bio: about)
                isSaving = false
                TPHaptic.success()
                RefreshSignal.shared.bumpProfile()
                router.pop()
                tpToast("Profile updated", tone: .success, symbol: "checkmark")
            }
        }
    }
}
