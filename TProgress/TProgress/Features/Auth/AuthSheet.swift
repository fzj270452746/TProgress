import SwiftUI
import AuthenticationServices

// MARK: - Mode

private enum AuthMode: String, CaseIterable, Identifiable {

    case signIn
    case create

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signIn: return "Sign in"
        case .create: return "Create account"
        }
    }

    var actionTitle: String {
        switch self {
        case .signIn: return "Sign in"
        case .create: return "Create my account"
        }
    }

    var loadingMessage: String {
        switch self {
        case .signIn: return "Signing you in"
        case .create: return "Setting things up"
        }
    }
}

// MARK: - Sheet

struct AuthSheet: View {

    @ObservedObject private var session = AppSession.shared

    @State private var mode: AuthMode = .signIn
    @State private var username = ""
    @State private var displayName = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var errorMessage: String?
    @State private var legalDocument: LegalDocument?
    @State private var appeared = false

    @FocusState private var focus: Field?

    @Namespace private var segment

    private enum Field: Hashable {
        case username, displayName, password, confirm
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        crest
                        headline
                        card
                    }
                    // This panel has no dock under it, so the dock clearance
                    // that used to sit here was reserving 112pt of nothing and
                    // pushing the Apple button off the bottom of the screen.
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboardNever()
                .tpDismissKeyboardOnTap()

                footer
            }

            closeButton
        }
        .preferredColorScheme(.dark)
        .sheet(item: $legalDocument) { document in
            LegalSheet(document: document)
        }
        .onAppear {
            DispatchQueue.main.async { withAnimation(TPMotion.gentle) { appeared = true } }
        }
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            TPBackdropView(style: .auth)
            TPArcBackdrop(color: Color.tpEmber.opacity(0.16), rings: 6, sweep: 0.70, verticalAnchor: 0.40)
            TPHalo(color: .tpEmber, spread: 1.75)
                .offset(y: -40)
            TPGrain(opacity: 0.05)
        }
        .ignoresSafeArea()
    }

    // Sized so the whole sign-in form, Apple button included, lands above the
    // fold on a standard phone. The mark is branding; a form the user cannot
    // see is a form the user does not fill in.
    private var crest: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(TPGradient.accent(.tpEmber).opacity(0.16))
                    .frame(width: 60, height: 60)

                TPMark(showsBaseline: true)
                    .stroke(
                        TPGradient.ember,
                        style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 32, height: 32)
            }
            .scaleEffect(appeared ? 1 : 0.86)
            .opacity(appeared ? 1 : 0)

            Text("TProgress")
                .font(TPFont.display(14, .bold))
                .foregroundColor(.tpCreamFaint)
        }
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    private var headline: some View {
        VStack(spacing: 10) {
            Text(mode == .signIn ? "Small things,\nkept." : "Start keeping\nyour streak.")
                .font(TPFont.display(34, .heavy))
                .foregroundColor(.tpCream)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .id(mode)

            if let prompt = session.authPrompt {
                Text(prompt)
                    .font(TPFont.ui(14))
                    .foregroundColor(.tpCreamDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .transition(.opacity)
            } else {
                Text("Log the page, the minute, the kilometre.\nThen do it again tomorrow.")
                    .font(TPFont.ui(14))
                    .foregroundColor(.tpCreamDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 34)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: Form

    private var card: some View {
        VStack(spacing: 18) {
            TPSegmented(items: AuthMode.allCases, selection: $mode, title: \.title, namespace: segment)
                .onChange(of: mode) { _ in
                    errorMessage = nil
                    withAnimation(TPMotion.snappy) { clearSecrets() }
                }

            VStack(spacing: 20) {
                TPTextField(
                    label: "Username",
                    placeholder: "yourname",
                    text: $username,
                    capitalization: .never,
                    submitLabel: .next,
                    symbol: "person",
                    onSubmit: { focus = mode == .signIn ? .password : .displayName }
                )
                .focused($focus, equals: .username)

                if mode == .create {
                    TPTextField(
                        label: "Display name",
                        placeholder: "How your name appears",
                        text: $displayName,
                        capitalization: .words,
                        submitLabel: .next,
                        symbol: "textformat",
                            onSubmit: { focus = .password }
                    )
                    .focused($focus, equals: .displayName)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                TPTextField(
                    label: "Password",
                    placeholder: mode == .signIn ? "Your password" : "At least 6 characters",
                    text: $password,
                    isSecure: true,
                    submitLabel: mode == .signIn ? .go : .next,
                    symbol: "lock",
                    onSubmit: { mode == .signIn ? submit() : (focus = .confirm) }
                )
                .focused($focus, equals: .password)

                if mode == .create {
                    TPTextField(
                        label: "Confirm password",
                        placeholder: "Type it once more",
                        text: $confirm,
                        isSecure: true,
                        submitLabel: .go,
                        symbol: "lock.rotation",
                            onSubmit: { submit() }
                    )
                    .focused($focus, equals: .confirm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            if let errorMessage {
                errorBanner(errorMessage)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            TPPrimaryButton(
                title: mode.actionTitle,
                isEnabled: canSubmit,
                action: submit
            )

            orDivider

            // The segmented control at the top of this card already switches to
            // account creation, so a second "create an account" button underneath
            // was saying the same thing twice and pushing Apple off the screen.
            appleButton
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.tpInkRaised.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.tpLine, lineWidth: 1)
                )
        )
        .padding(.horizontal, TPMetric.gutter)
        .offset(y: appeared ? 0 : 22)
        .opacity(appeared ? 1 : 0)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.tpDanger)

            Text(message)
                .font(TPFont.ui(13, .medium))
                .foregroundColor(.tpCream)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.tpBloom.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.tpBloom.opacity(0.3), lineWidth: 1)
        )
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            TPFadeRule()
            Text.tpLabel("or", size: 10, tracking: 1.6)
            TPFadeRule()
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(
            .continue,
            onRequest: { request in
                request.requestedScopes = [.fullName, .email]
            },
            onCompletion: { result in
                handleApple(result)
            }
        )
        .signInWithAppleButtonStyle(.white)
        .frame(height: 54)
        .clipShape(Capsule(style: .continuous))
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 0) {
            TPFadeRule()

            TPLegalFooter { document in
                legalDocument = document
            }
            .padding(.horizontal, 26)
            .padding(.top, 14)
            .padding(.bottom, 10)
        }
        .background(
            TPBarFill(edge: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                TPIconButton(
                    symbol: "xmark",
                    size: 36,
                    tint: .tpCreamDim,
                    background: Color.tpInkRaised.opacity(0.85),
                    action: { session.dismissAuth() }
                )
            }
            .padding(.horizontal, TPMetric.gutter)
            .padding(.top, 16)
            Spacer()
        }
    }

    // MARK: Actions

    private var canSubmit: Bool {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.isEmpty else { return false }
        if mode == .create {
            return !confirm.isEmpty
        }
        return true
    }

    private func clearSecrets() {
        password = ""
        confirm = ""
    }

    private func submit() {
        focus = nil
        TPKeyboard.dismiss()
        errorMessage = nil

        let name = username
        let shown = displayName
        let secret = password
        let repeated = confirm

        Task {
            await TPLoadingRun.run(message: mode.loadingMessage) {
                do {
                    switch mode {
                    case .signIn:
                        try session.signIn(username: name, password: secret)
                    case .create:
                        try session.signUp(
                            username: name,
                            displayName: shown,
                            password: secret,
                            confirm: repeated
                        )
                    }
                    TPHaptic.success()
                } catch {
                    let message = (error as? AuthError)?.errorDescription
                        ?? "Something went wrong. Please try again."
                    withAnimation(TPMotion.snappy) { errorMessage = message }
                }
            }
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        errorMessage = nil

        switch result {
        case .success(let authorization):
            Task {
                await TPLoadingRun.run(message: "Signing you in") {
                    do {
                        try session.handleApple(authorization)
                        TPHaptic.success()
                    } catch {
                        let message = (error as? AuthError)?.errorDescription
                            ?? "Apple sign in could not be completed."
                        withAnimation(TPMotion.snappy) { errorMessage = message }
                    }
                }
            }

        case .failure(let error):
            // A cancelled sheet is not an error worth shouting about.
            let code = (error as NSError).code
            if code == ASAuthorizationError.canceled.rawValue { return }
            withAnimation(TPMotion.snappy) {
                errorMessage = "Apple sign in is unavailable right now. You can use a username and password instead."
            }
        }
    }
}

// MARK: - Legal push

/// Legal documents opened from inside the auth sheet need their own container,
/// since the sheet is not part of the app's navigation stack.
struct LegalSheet: View {

    let document: LegalDocument

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: document.title,
                subtitle: "Last updated October 2026",
                onBack: { dismiss() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(document.preamble)
                        .font(TPFont.display(17))
                        .foregroundColor(.tpCream)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    TPFadeRule()

                    ForEach(Array(document.sections.enumerated()), id: \.offset) { index, section in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 9) {
                                Text(String(format: "%02d", index + 1))
                                    .font(TPFont.figure(12, .bold))
                                    .foregroundColor(.tpEmber)
                                Text(section.title)
                                    .font(TPFont.display(18, .bold))
                                    .foregroundColor(.tpCream)
                            }
                            Text(section.body)
                                .font(TPFont.ui(14.5))
                                .foregroundColor(.tpCreamDim)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, TPMetric.gutter)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tpBackdrop(.deep)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Small helper

private extension View {

    /// `.scrollDismissesKeyboard` is iOS 16; this modifier is a no-op that keeps
    /// the call site readable, with dismissal handled by `tpDismissKeyboardOnTap`.
    func scrollDismissesKeyboardNever() -> some View { self }
}
