import SwiftUI
import Combine
import AVKit
import UIKit

// MARK: - Presenter

/// Full screen viewing is a single app-level surface rather than a per-page
/// sheet, so an image opened from the feed and one opened from search behave
/// identically.
final class MediaPresenter: ObservableObject {

    static let shared = MediaPresenter()

    /// A clip arrives as a resolved `URL`; a still arrives as the name it was
    /// addressed by and is looked up on display. The still stays a `String`
    /// rather than a `UIImage` so the enum remains comparable, which is what
    /// lets `@Published var content` publish a change at all.
    enum Content: Equatable {
        case image(String, seed: Int64)
        case video(URL, seed: Int64)
    }

    @Published var content: Content?
    @Published var isPresented = false

    private init() {}

    func show(_ content: Content) {
        self.content = content
        withAnimation(TPMotion.gentle) { isPresented = true }
    }

    func dismiss() {
        withAnimation(TPMotion.gentle) { isPresented = false }
        content = nil
    }
}

// MARK: - Viewer

struct TPFullscreenMedia: View {

    let content: MediaPresenter.Content
    let onClose: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch content {
            case .image(let name, let seed):
                imageView(pathOrName: name, seed: seed)
            case .video(let url, _):
                videoView(url: url)
            }

            VStack {
                HStack {
                    Spacer()
                    TPIconButton(
                        symbol: "xmark",
                        size: 40,
                        tint: .tpCream,
                        background: Color.white.opacity(0.12),
                        bordered: false,
                        action: onClose
                    )
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)

                Spacer()
            }
        }
        .onTapGesture {
            if case .image = content, scale <= 1.01 { onClose() }
        }
    }

    // MARK: Image

    private func imageView(pathOrName: String, seed: Int64) -> some View {
        // Same rule the tiles use, so tapping a catalogue image opens the image
        // rather than dropping through to proc art.
        let uiImage = TPIconResolver.image(pathOrName: pathOrName)

        return Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                TPArt(seed: seed, cornerRadius: 0)
                    .aspectRatio(0.8, contentMode: .fit)
            }
        }
        .scaleEffect(scale)
        .offset(offset)
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = min(max(lastScale * value, 1), 4)
                }
                .onEnded { _ in
                    lastScale = scale
                    if scale <= 1.02 { resetZoom() }
                }
        )
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    guard scale > 1.01 else { return }
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in lastOffset = offset }
        )
        .onTapGesture(count: 2) {
            withAnimation(TPMotion.spring) {
                if scale > 1.01 {
                    resetZoom()
                } else {
                    scale = 2.2
                    lastScale = 2.2
                }
            }
        }
    }

    private func resetZoom() {
        withAnimation(TPMotion.spring) {
            scale = 1
            lastScale = 1
            offset = .zero
            lastOffset = .zero
        }
    }

    // MARK: Video

    private func videoView(url: URL) -> some View {
        FullscreenVideoPlayer(url: url)
            .ignoresSafeArea()
    }
}

// MARK: - Fullscreen video
//
// `VideoPlayer` from AVKit brings the system transport controls, which is the
// right behaviour once a clip is genuinely full screen.

private struct FullscreenVideoPlayer: View {

    let url: URL

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear { player.play() }
            } else {
                ProgressView()
                    .tint(.tpCream)
            }
        }
        .onAppear {
            if player == nil { player = AVPlayer(url: url) }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
