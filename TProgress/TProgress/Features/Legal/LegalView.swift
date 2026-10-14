import SwiftUI

// MARK: - Footer
//
// The line the brief requires under every entry point into the account flow.
// "Terms of Service", "Privacy Policy" and "EULA" are live links.

struct TPLegalFooter: View {

    var compact: Bool = false
    var onOpen: (LegalDocument) -> Void

    private var markdown: String {
        "By continuing you agree with [Terms of Service](tp://terms) & [Privacy Policy](tp://privacy)\nYou also accept the [EULA](tp://eula)."
    }

    var body: some View {
        // A String built at runtime is rendered verbatim by Text, so the
        // markdown has to be parsed explicitly — otherwise the link syntax is
        // shown to the reader as literal brackets.
        Text(attributed)
            .font(TPFont.ui(compact ? 11 : 12))
            .foregroundColor(.tpCreamFaint)
            .multilineTextAlignment(.center)
            .lineSpacing(3.5)
            .tint(.tpCream)
            .environment(\.openURL, OpenURLAction { url in
                if let document = LegalDocument(rawValue: url.host ?? "") {
                    onOpen(document)
                }
                return .handled
            })
    }

    private var attributed: AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace

        guard var parsed = try? AttributedString(markdown: markdown, options: options) else {
            return AttributedString(markdown)
        }

        // The brief asks for these to be highlighted, so they are underlined as
        // well as tinted.
        for run in parsed.runs where run.link != nil {
            parsed[run.range].underlineStyle = .single
        }
        return parsed
    }
}

// MARK: - Document

struct LegalView: View {

    let document: LegalDocument

    @ObservedObject private var router = Router.shared

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: document.title,
                subtitle: "Last updated October 2026",
                onBack: { router.pop() }
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

                    hostedNote

                    Text("Questions about this document can be sent to legal@tprogress.app.")
                        .font(TPFont.ui(12.5))
                        .foregroundColor(.tpCreamFaint)
                        .padding(.top, 4)
                }
                .padding(.horizontal, TPMetric.gutter)
                .padding(.bottom, 60)
            }
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
    }

    /// The full text of the document is rendered above, so there is nothing to
    /// link out to. The line stands as a note rather than an entry point.
    private var hostedNote: some View {
        Text("Read the hosted version")
            .font(TPFont.ui(14, .semibold))
            .foregroundColor(.tpEmber)
            .padding(.top, 6)
    }
}

// MARK: - Copy

extension LegalDocument {

    var preamble: String {
        switch self {
        case .terms:
            return "TProgress is a place to record small, repeatable things. These terms describe what you can expect from us and what we expect from you."
        case .privacy:
            return "We collect the least we can and keep it on your device wherever possible. This page explains exactly what that means."
        case .eula:
            return "This agreement covers your licence to use the TProgress application on Apple devices."
        }
    }

    var sections: [(title: String, body: String)] {
        switch self {
        case .terms:
            return [
                ("Your account",
                 "You need an account to post, comment, gift or message. Keep your credentials to yourself. You are responsible for activity that happens under your account."),
                ("What belongs here",
                 "Progress you actually did. Encouragement for other people. Questions when you are stuck.\n\nHarassment, illegal content, spam, and anything designed to mislead do not belong here and will be removed."),
                ("Gifts",
                 "Gifts are consumable purchases made through the App Store. They have no cash value, cannot be transferred, and cannot be refunded once sent. All payment processing is handled by Apple."),
                ("Messaging",
                 "You can only message people you have mutually added. We do not offer random or anonymous chat, and we do not match strangers."),
                ("Content you post",
                 "You keep ownership of everything you post. You grant us the licence needed to store it and show it to the people you share it with."),
                ("Ending your account",
                 "You can delete your account at any time from Settings. Deletion removes your posts, replies and conversations from this device immediately.")
            ]
        case .privacy:
            return [
                ("What we store",
                 "Your username, a salted hash of your password, your profile details, and the content you create. Your session token is kept in the device keychain."),
                ("Where it lives",
                 "On your device. TProgress does not operate an advertising profile, does not sell data, and does not track you across other apps or websites."),
                ("Photos and videos",
                 "Media you attach is copied into the app's own storage so your post keeps its attachments. We only access the items you explicitly choose."),
                ("Purchases",
                 "Gift purchases are processed by Apple. We receive confirmation that a purchase completed, never your payment details."),
                ("Your controls",
                 "You can edit your profile, remove any post or reply, block any account, and delete your account and its data from Settings at any time."),
                ("Contact",
                 "Privacy questions can be sent to privacy@tprogress.app.")
            ]
        case .eula:
            return [
                ("Licence",
                 "You are granted a personal, non-transferable licence to use TProgress on Apple devices that you own or control, as permitted by the App Store Terms of Service."),
                ("Restrictions",
                 "You may not copy, modify, distribute, sell, lease, reverse engineer, or attempt to derive the source code of the application, except where such restriction is prohibited by law."),
                ("Apple's role",
                 "Apple is not a party to this agreement and has no obligation to provide maintenance or support for the application. Apple is a third party beneficiary of this agreement."),
                ("Maintenance and support",
                 "We are solely responsible for maintenance and support. Any questions, complaints or claims should be directed to support@tprogress.app."),
                ("Warranty",
                 "The application is provided \"as is\", without warranty of any kind, to the maximum extent permitted by applicable law."),
                ("Compliance",
                 "You confirm that you are not located in a country subject to a U.S. Government embargo, and that you are not listed on any U.S. Government prohibited or restricted party list.")
            ]
        }
    }
}
