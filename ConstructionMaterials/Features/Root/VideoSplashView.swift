import SwiftUI
import AVFoundation
import UIKit

struct VideoSplashView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var player: AVPlayer?
    @State private var didFinish = false

    private let background = Color(red: 0.867, green: 0.841, blue: 0.802)
    private let backgroundUIColor = UIColor(red: 0.867, green: 0.841, blue: 0.802, alpha: 1)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            if let player {
                PlayerLayerView(player: player, backgroundColor: backgroundUIColor)
                    .ignoresSafeArea()
                VideoEdgeBlend(background: background)
                    .allowsHitTesting(false)
            }

            VStack {
                HStack {
                    Spacer()

                    Button {
                        finish()
                    } label: {
                        Text("Bỏ qua")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.68))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.55), in: Capsule())
                    }
                    .accessibilityLabel("Bỏ qua video giới thiệu")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                VStack(spacing: 8) {
                    Text("Quản lý vật liệu")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.black.opacity(0.72))

                    ProgressView()
                        .tint(Color.black.opacity(0.45))
                }
                .padding(.bottom, 42)
            }
        }
        .statusBarHidden(true)
        .onAppear(perform: startIfNeeded)
        .onDisappear(perform: stop)
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard let item = notification.object as? AVPlayerItem,
                  item === player?.currentItem else {
                return
            }
            finish()
        }
    }

    private func startIfNeeded() {
        guard !reduceMotion else {
            finish()
            return
        }

        if let player {
            player.play()
            return
        }

        guard let url = Bundle.main.url(forResource: "splash-intro", withExtension: "mp4") else {
            finish()
            return
        }

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.isMuted = true
        newPlayer.actionAtItemEnd = .pause
        player = newPlayer
        newPlayer.play()
    }

    private func stop() {
        player?.pause()
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        player?.pause()
        onFinished()
    }
}

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let backgroundColor: UIColor

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.backgroundColor = backgroundColor
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.backgroundColor = backgroundColor.cgColor
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

/// Làm mờ dải viền trên/dưới của video để màu nền video hoà vào nền splash.
private struct VideoEdgeBlend: View {
    let background: Color

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width < proxy.size.height {
                let fade: CGFloat = 36
                let videoHeight = proxy.size.width * 9 / 16
                let topInset = max(0, (proxy.size.height - videoHeight) / 2)

                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: topInset)
                    LinearGradient(
                        colors: [background, background.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: fade)
                    Spacer(minLength: 0)
                    LinearGradient(
                        colors: [background.opacity(0), background],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: fade)
                    Color.clear
                        .frame(height: topInset)
                }
            }
        }
        .ignoresSafeArea()
    }
}
