import SwiftUI
import UIKit

// MARK: - About

struct AboutView: View {

    @ObservedObject private var router = Router.shared

    @State private var appeared = false

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            TPPageHeader(title: "About", subtitle: "What this is", onBack: { router.pop() })

            ScrollView {
                VStack(spacing: 22) {
                    crest
                    statement
                    principles
                    legalLinks
                    signature
                }
                .padding(.horizontal, TPMetric.gutter)
                .padding(.bottom, 50)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                // A pushed page covers the tab root, so it paints its own ground. Kept
                // deeper than a tab's so forms and long reads stay comfortable.
                TPBackdropView(style: .deep)
                TPArcBackdrop(color: Color.tpEmber.opacity(0.12), rings: 5, sweep: 0.66, verticalAnchor: 0.18)
                TPGrain(opacity: 0.04)
            }
            .ignoresSafeArea()
        )
        .onAppear {
            DispatchQueue.main.async { withAnimation(TPMotion.gentle) { appeared = true } }
        }
    }

    // MARK: Crest

    private var crest: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(TPGradient.accent(.tpEmber).opacity(0.14))
                    .frame(width: 92, height: 92)

                TPMark(showsBaseline: true)
                    .stroke(
                        TPGradient.ember,
                        style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 48, height: 48)
            }
            .scaleEffect(appeared ? 1 : 0.88)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 6) {
                Text("TProgress")
                    .font(TPFont.display(30, .heavy))
                    .foregroundColor(.tpCream)

                Text(version)
                    .font(TPFont.ui(12))
                    .foregroundColor(.tpCreamFaint)
            }
        }
        .padding(.top, 22)
    }

    // MARK: Statement

    private var statement: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Small things, kept.")
                .font(TPFont.display(24, .bold))
                .foregroundColor(.tpCream)

            Text("""
            TProgress is a place to record the small, repeatable things you actually did today. Five pages on a bus. Ten minutes at the piano. Three kilometres in the rain.

            There are no leaderboards and no follower contests. The feed rewards people who come back, not people who do the most. A missed day is not a failure here — returning is the practice.
            """)
            .font(TPFont.ui(14.5))
            .foregroundColor(.tpCreamDim)
            .lineSpacing(5.5)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
    }

    // MARK: Principles

    private var principles: some View {
        VStack(alignment: .leading, spacing: 14) {
            TPSectionHeader(label: "What is inside", title: "The parts that matter")

            VStack(spacing: 10) {
                principle(
                    symbol: "circle.hexagongrid",
                    tint: .tpMint,
                    title: "Circles",
                    body: "Shared practices. Members log the same small thing and see each other do it, without a ranking."
                )
                principle(
                    symbol: "checkmark.seal",
                    tint: .tpEmber,
                    title: "Daily check-ins",
                    body: "A single tap to record today. The log is deliberately boring so it stays honest."
                )
                principle(
                    symbol: "chart.xyaxis.line",
                    tint: .tpLilac,
                    title: "Stage recaps",
                    body: "Every thirty days your effort is charted: the trend, the gaps, and what the returning cost you."
                )
                principle(
                    symbol: "link",
                    tint: .tpSky,
                    title: "Messages bound to actions",
                    body: "Threads carry the sessions you log inside them. Conversation here starts from something you did."
                )
                principle(
                    symbol: "gift",
                    tint: .tpSun,
                    title: "Gifts",
                    body: "Seven tokens, from a single ember to a supernova, for the posts that moved you to keep going."
                )
                principle(
                    symbol: "arrow.down.circle",
                    tint: .tpMint,
                    title: "A floor",
                    body: "Every circle can name the smallest version that still counts — out the door for five minutes. Doing only that counts the same as any other day."
                )
                principle(
                    symbol: "moon.zzz",
                    tint: .tpSky,
                    title: "Rest, declared in advance",
                    body: "A day off, said before it happens, keeps the run alive and costs nothing. Said afterwards it is not a rest, so the log does not take it."
                )
                principle(
                    symbol: "square.grid.3x3",
                    tint: .tpBloom,
                    title: "The way back",
                    body: "One page measures how long you are usually away before you return — because coming back is the practice, and a streak cannot see it."
                )
            }
        }
    }

    private func principle(symbol: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 40, height: 40)

                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(TPFont.ui(15, .semibold))
                    .foregroundColor(.tpCream)

                Text(body)
                    .font(TPFont.ui(13))
                    .foregroundColor(.tpCreamDim)
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
    }

    // MARK: Legal

    private var legalLinks: some View {
        VStack(spacing: 0) {
            TPRow(symbol: "doc.text", title: "Terms of Service", accent: .tpEmber) {
                router.push(.legal(.terms))
            }
            TPFadeRule()
            TPRow(symbol: "hand.raised", title: "Privacy Policy", accent: .tpMint) {
                router.push(.legal(.privacy))
            }
            TPFadeRule()
            TPRow(symbol: "signature", title: "End User Licence Agreement", accent: .tpLilac) {
                router.push(.legal(.eula))
            }
            TPFadeRule()
            TPRow(symbol: "envelope", title: "Contact support", detail: "support@tprogress.app", accent: .tpSky, showsChevron: false) {
                UIPasteboard.general.string = "support@tprogress.app"
                tpToast("Address copied", tone: .success, symbol: "doc.on.doc")
            }
        }
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
    }

    // MARK: Signature

    private var signature: some View {
        VStack(spacing: 10) {
            TPMark(showsBaseline: false)
                .stroke(Color.tpLine, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 28, height: 28)

            Text("Made for people who keep going.")
                .font(TPFont.display(14))
                .foregroundColor(.tpCreamFaint)
        }
        .padding(.top, 12)
    }
}
