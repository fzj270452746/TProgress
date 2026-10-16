import SwiftUI
import UIKit
import WebKit

// MARK: - Phase
//
// A hosted document can be slow or unreachable. A blank screen in either case
// reads as a broken app, so the page reports what it is doing instead.

enum TPLegalPagePhase: Equatable {
    case loading
    case loaded
    case failed(reason: String)
}

// MARK: - Web view

/// The legal documents are published and maintained on PrivacyPolicies.com, so
/// the app renders the hosted page rather than a copy of its text. The two can
/// never drift apart, and an edit there is live here without a release.
struct TPLegalWebView: UIViewRepresentable {

    let url: URL
    @Binding var phase: TPLegalPagePhase

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, phase: $phase)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // A document one reads once leaves nothing behind: no cookies, no
        // storage, nothing carried into the next session.
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        // The page paints its own white canvas, so the view stays transparent
        // until it does. The app's ground shows through the load instead of a
        // white rectangle, and an over-scroll at the end of the document
        // reveals it too.
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        context.coordinator.load(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // SwiftUI re-runs this on every state change. Reloading here would throw
        // the reader back to the top of a document they are still reading, so
        // only a genuinely different document is fetched.
        guard context.coordinator.url != url else { return }
        context.coordinator.url = url
        context.coordinator.load(in: webView)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {

        /// The document this view is showing.
        var url: URL

        private let phase: Binding<TPLegalPagePhase>

        init(url: URL, phase: Binding<TPLegalPagePhase>) {
            self.url = url
            self.phase = phase
        }

        func load(in webView: WKWebView) {
            phase.wrappedValue = .loading
            webView.load(URLRequest(url: url))
        }

        // MARK: Navigation

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Sub-frames and in-page anchors are the document's own business.
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
            guard isMainFrame, let target = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if Self.belongsToHost(target) {
                decisionHandler(.allow)
            } else {
                // Anything leaving the document — the host's other pages, a
                // mailto — is handed to the system, where the reader can see
                // where it is going before it opens.
                decisionHandler(.cancel)
                UIApplication.shared.open(target)
            }
        }

        private static func belongsToHost(_ url: URL) -> Bool {
            guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
                return false
            }
            guard let host = url.host?.lowercased() else { return false }
            return host == "privacypolicies.com" || host.hasSuffix(".privacypolicies.com")
        }

        // MARK: Progress

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            phase.wrappedValue = .loaded
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            report(error)
        }

        private func report(_ error: Error) {
            let failure = error as NSError

            // A cancelled load is the app's own doing — a link sent out to the
            // system — not a document that failed to open.
            guard failure.domain != NSURLErrorDomain || failure.code != NSURLErrorCancelled else {
                return
            }

            phase.wrappedValue = .failed(reason: failure.localizedDescription)
        }
    }
}

// MARK: - Document

/// The screen both entry points share: the page pushed from About, and the
/// sheet the auth and compose flows raise. The chrome above belongs to the app;
/// everything below it is the published document, unmodified.
struct LegalDocumentPage: View {

    let document: LegalDocument
    let onBack: () -> Void

    @State private var phase: TPLegalPagePhase = .loading

    /// Bumping this rebuilds the web view, which is the only reliable way to
    /// restart a load that has wedged.
    @State private var attempt = 0

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(
                title: document.title,
                subtitle: document.host,
                onBack: onBack
            )

            ZStack {
                TPLegalWebView(url: document.url, phase: $phase)
                    .id(attempt)

                if phase != .loaded {
                    cover
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(TPMotion.gentle, value: phase)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                // A pushed page covers the tab root, so it paints its own ground.
                // Kept deeper than a tab's so a long read stays comfortable.
                TPBackdropView(style: .deep)
                TPGrain(opacity: 0.04)
            }
            .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
    }

    /// While the page is on its way — or on the floor — the reader sees the
    /// app's own ground rather than a half-painted document.
    private var cover: some View {
        ZStack {
            TPBackdropView(style: .deep)

            switch phase {
            case .loading:
                loading
            case .failed(let reason):
                failure(reason)
            case .loaded:
                EmptyView()
            }
        }
    }

    private var loading: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.tpEmber)
                .scaleEffect(1.15)

            Text.tpLabel("Loading document", size: 10, tracking: 1.8)
        }
    }

    private func failure(_ reason: String) -> some View {
        TPEmptyState(
            symbol: "exclamationmark.triangle",
            title: "Document unavailable",
            message: "The hosted document could not be opened.\n\n\(reason)",
            actionTitle: "Try again",
            action: reload
        )
        .padding(.horizontal, TPMetric.gutter)
    }

    private func reload() {
        TPHaptic.tap()
        phase = .loading
        attempt += 1
    }
}

// MARK: - Addresses

extension LegalDocument {

    /// The published text. Both the terms and the privacy policy are kept on
    /// one hosted page; the EULA has its own.
    var url: URL {
        switch self {
        case .terms, .privacy:
            return URL(string: "https://www.privacypolicies.com/live/b6a123e5-c0d0-4549-9b2e-cef160ddd229")!
        case .eula:
            return URL(string: "https://www.privacypolicies.com/live/669a4d89-28d5-4e58-8566-1e4af1ebcd26")!
        }
    }

    /// Shown under the title so the reader knows the text is served from a
    /// published source rather than written into the build.
    var host: String { "privacypolicies.com" }
}
