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

// MARK: - Page

/// The pushed entry point, reached from About. The document itself is the
/// hosted page, rendered by `LegalDocumentPage`.
struct LegalView: View {

    let document: LegalDocument

    @ObservedObject private var router = Router.shared

    var body: some View {
        LegalDocumentPage(document: document) { router.pop() }
    }
}
