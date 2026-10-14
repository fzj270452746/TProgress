import Foundation
import SwiftUI
import PhotosUI
import UIKit
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Library

/// Picked assets are copied into the app's own container so a post keeps its
/// media even if the original is removed from the photo library.
enum TPMediaLibrary {

    static var directory: URL {
        let base = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let media = base.appendingPathComponent("Media", isDirectory: true)
        if !FileManager.default.fileExists(atPath: media.path) {
            try? FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        }
        return media
    }

    @discardableResult
    static func saveImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.88) else { return nil }
        let url = directory.appendingPathComponent(UUID().uuidString + ".jpg")
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            return nil
        }
    }

    @discardableResult
    static func saveVideo(from source: URL) -> String? {
        let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
        let destination = directory.appendingPathComponent(UUID().uuidString + "." + ext)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            return destination.path
        } catch {
            return nil
        }
    }

    // MARK: - Clips
    //
    // Stills arrive by catalogue name and resolve inside `TPMediaFrame`. Clips
    // cannot: `AVPlayer` needs a file URL, and a data set would have to be
    // written back out to disk before it could play. So a clip ships as a bare
    // file at the bundle root — drop `video_music_poster.mp4` in beside the
    // catalogue and it is picked up, no code change and no asset entry.

    private static let clipExtensions = ["mp4", "mov", "m4v"]

    /// A clip shipped with the app, addressed by plain name (`video_poster_1`).
    static func bundledClip(named name: String) -> URL? {
        guard !name.isEmpty, !name.contains("/") else { return nil }
        for ext in clipExtensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) { return url }
        }
        return nil
    }

    /// A picked file in the container, or a clip shipped with the app.
    static func videoURL(forAsset name: String?) -> URL? {
        guard let name, !name.isEmpty else { return nil }
        if name.contains("/") {
            return FileManager.default.fileExists(atPath: name) ? URL(fileURLWithPath: name) : nil
        }
        return bundledClip(named: name)
    }

    /// Which shipped clip stands in for which seeded video, keyed by the name the
    /// seed gave the tile. The seed only carries a still (`video_music_poster`),
    /// so the footage has to be married to it here: the piano clip belongs to
    /// Piano Practice and the pool clip to Cold Plunge, which is the one that
    /// reads as water. A topic with no entry keeps its still and plays nothing.
    private static let clipStandsIn: [String: String] = [
        "video_music_poster": "video_poster_1",
        "video_cold_poster": "video_poster_2"
    ]

    /// The clip a media row plays.
    ///
    /// A container path is the user's own footage and there is no honest stand-in
    /// for it — falling back there would play a shipped clip as if the poster had
    /// recorded it. A catalogue-style name makes no such claim, so it falls back
    /// to whichever clip was paired with it.
    static func clipURL(forAsset name: String?) -> URL? {
        guard let name, !name.isEmpty else { return nil }
        if name.contains("/") { return videoURL(forAsset: name) }
        // A clip named after the tile itself wins over the stand-in, so dropping
        // `video_music_poster.mp4` in beside the others overrides the pairing.
        if let own = bundledClip(named: name) { return own }
        guard let standIn = clipStandsIn[name] else { return nil }
        return bundledClip(named: standIn)
    }

    // MARK: Frames

    // Three seeded posts share one clip and the feed rebuilds its window on every
    // refresh, so the same first frame would otherwise be decoded over and over.
    private static let frameCache = NSCache<NSString, UIImage>()
    private static let durationCache = NSCache<NSURL, NSNumber>()

    private static func frameKey(_ url: URL, _ seconds: Double) -> NSString {
        "\(url.absoluteString)#\(seconds)" as NSString
    }

    static func thumbnail(forVideoAt url: URL, at seconds: Double = 1.0) -> UIImage? {
        let key = frameKey(url, seconds)
        if let cached = frameCache.object(forKey: key) { return cached }

        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        // A portrait clip arrives rotated unless the track transform is applied.
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 900, height: 900)
        // The default tolerance lets AVFoundation return any nearby keyframe —
        // often a black opening frame — so ask for the requested second exactly.
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let time = CMTime(seconds: min(seconds, max(asset.duration.seconds - 0.1, 0)), preferredTimescale: 600)
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else { return nil }

        let image = UIImage(cgImage: cgImage)
        frameCache.setObject(image, forKey: key)
        return image
    }

    static func thumbnail(forVideoAt path: String, at seconds: Double = 1.0) -> UIImage? {
        thumbnail(forVideoAt: URL(fileURLWithPath: path), at: seconds)
    }

    static func duration(ofVideoAt url: URL) -> Double {
        if let cached = durationCache.object(forKey: url as NSURL) { return cached.doubleValue }

        // Synchronous on purpose: the deployment target is iOS 15, so
        // `load(.duration)` is unavailable and this access is not deprecated.
        let seconds = AVURLAsset(url: url).duration.seconds
        let value = seconds.isFinite ? seconds : 0
        // A clip that has not been read yet reports 0; caching that would pin it.
        if value > 0 { durationCache.setObject(NSNumber(value: value), forKey: url as NSURL) }
        return value
    }

    static func duration(ofVideoAt path: String) -> Double {
        duration(ofVideoAt: URL(fileURLWithPath: path))
    }

    /// `1:23`. Shared by the seeded durations and the real length read off a
    /// clip, so a badge reads the same whichever it came from.
    static func label(forDuration seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func remove(path: String) {
        guard !path.isEmpty else { return }
        try? FileManager.default.removeItem(atPath: path)
    }
}

// MARK: - Picker

/// `PhotosPicker` is iOS 16, so the UIKit picker is wrapped directly. The
/// selection limit is enforced here as well as in the caller.
struct TPMediaPicker: UIViewControllerRepresentable {

    var selectionLimit: Int
    var filter: PHPickerFilter
    var onComplete: ([PendingMedia]) -> Void
    var onCancel: () -> Void = {}

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = filter
        configuration.selectionLimit = max(1, selectionLimit)
        configuration.preferredAssetRepresentationMode = .current

        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {

        private let onComplete: ([PendingMedia]) -> Void
        private let onCancel: () -> Void

        init(onComplete: @escaping ([PendingMedia]) -> Void, onCancel: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                onCancel()
                return
            }

            let group = DispatchGroup()
            var collected: [PendingMedia] = []
            let lock = NSLock()

            for result in results {
                let provider = result.itemProvider

                if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    group.enter()
                    provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                        defer { group.leave() }
                        guard let url, let saved = TPMediaLibrary.saveVideo(from: url) else { return }

                        let item = PendingMedia(
                            path: saved,
                            isVideo: true,
                            duration: TPMediaLibrary.duration(ofVideoAt: saved),
                            thumbnail: TPMediaLibrary.thumbnail(forVideoAt: saved)
                        )
                        lock.lock(); collected.append(item); lock.unlock()
                    }
                } else if provider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    provider.loadObject(ofClass: UIImage.self) { object, _ in
                        defer { group.leave() }
                        guard let image = object as? UIImage,
                              let saved = TPMediaLibrary.saveImage(image) else { return }

                        let item = PendingMedia(path: saved, isVideo: false, duration: 0, thumbnail: image)
                        lock.lock(); collected.append(item); lock.unlock()
                    }
                }
            }

            group.notify(queue: .main) {
                self.onComplete(collected)
            }
        }
    }
}

// MARK: - Video player surface
//
// Wrapped rather than used directly so aspect and controls stay consistent and
// full screen can be entered from anywhere in the app.

struct TPVideoSurface: View {

    let url: URL
    var showsControls: Bool = true

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.tpInk

            if let player {
                VideoPlayerLayerView(player: player)
            } else {
                TPArt(seed: Int64(url.absoluteString.hashValue % 5000))
            }
        }
        .onAppear { prepare() }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func prepare() {
        guard player == nil else {
            player?.play()
            return
        }
        let created = AVPlayer(url: url)
        created.isMuted = false
        player = created
        created.play()
    }
}

/// Bare `AVPlayerLayer` host. Deliberately without the system transport controls
/// so playback chrome matches the rest of the app.
struct VideoPlayerLayerView: UIViewRepresentable {

    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.backgroundColor = .clear
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: PlayerContainerView, context: Context) {
        view.playerLayer.player = player
    }

    final class PlayerContainerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
