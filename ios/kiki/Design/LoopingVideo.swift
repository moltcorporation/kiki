import AVFoundation
import SwiftUI

/// A muted, looping, full-bleed background video over a matching still.
///
/// The still shows instantly (before the first frame decodes) and instead of
/// the video when Reduce Motion is on. Playback pauses when the app leaves
/// the foreground. Ship videos without an audio track so they never
/// interrupt the user's music.
struct LoopingVideo: View {
    /// Bundled `.mp4` name without extension.
    let video: String
    /// Bundled image file name, e.g. the video's first frame.
    let poster: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image = UIImage(named: poster) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                if !reduceMotion, let url = Bundle.main.url(forResource: video, withExtension: "mp4") {
                    PlayerLayerView(url: url, isPlaying: scenePhase == .active)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct PlayerLayerView: UIViewRepresentable {
    let url: URL
    let isPlaying: Bool

    func makeUIView(context: Context) -> PlayerView { PlayerView(url: url) }

    func updateUIView(_ view: PlayerView, context: Context) {
        if isPlaying { view.player.play() } else { view.player.pause() }
    }

    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.player.pause()
    }
}

private final class PlayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init(url: URL) {
        super.init(frame: .zero)
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        let playerLayer = layer as! AVPlayerLayer
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
