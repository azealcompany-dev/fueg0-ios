import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    let videoId: String
    var playNonce: Int
    var onPlaying: () -> Void
    var onError: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPlaying: onPlaying, onError: onError)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let user = WKUserContentController()
        user.add(context.coordinator, name: "fueg0")
        config.userContentController = user

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.load(videoId: videoId)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onPlaying = onPlaying
        context.coordinator.onError = onError
        if context.coordinator.loadedId != videoId {
            context.coordinator.load(videoId: videoId)
        } else if playNonce != context.coordinator.lastPlayNonce {
            context.coordinator.lastPlayNonce = playNonce
            context.coordinator.play()
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "fueg0")
        uiView.stopLoading()
        coordinator.webView = nil
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var onPlaying: () -> Void
        var onError: () -> Void
        weak var webView: WKWebView?
        var loadedId = ""
        var lastPlayNonce = 0

        init(onPlaying: @escaping () -> Void, onError: @escaping () -> Void) {
            self.onPlaying = onPlaying
            self.onError = onError
        }

        func load(videoId: String) {
            loadedId = videoId
            let html = Self.html(videoId: videoId)
            webView?.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
        }

        func play() {
            webView?.evaluateJavaScript("window.fueg0Play && window.fueg0Play();")
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            let body = (message.body as? String) ?? ""
            if body == "playing" {
                DispatchQueue.main.async { self.onPlaying() }
            } else if body.hasPrefix("error") {
                DispatchQueue.main.async { self.onError() }
            }
        }

        private static func html(videoId: String) -> String {
            let id = String(videoId.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }.prefix(20))
            return """
            <!DOCTYPE html>
            <html>
            <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
            <style>
              html, body { margin: 0; background: #000; height: 100%; overflow: hidden; }
              #player { position: absolute; inset: 0; }
            </style>
            </head>
            <body>
            <div id="player"></div>
            <script>
              var tag = document.createElement('script');
              tag.src = "https://www.youtube.com/iframe_api";
              document.head.appendChild(tag);
              var player;
              function onYouTubeIframeAPIReady() {
                player = new YT.Player('player', {
                  width: '100%',
                  height: '100%',
                  videoId: '\(id)',
                  playerVars: {
                    autoplay: 1,
                    playsinline: 1,
                    rel: 0,
                    modestbranding: 1,
                    controls: 0,
                    fs: 0,
                    cc_load_policy: 0,
                    origin: 'https://www.youtube.com'
                  },
                  events: {
                    onReady: function(e) { e.target.playVideo(); },
                    onStateChange: function(e) {
                      if (e.data === 1) {
                        window.webkit.messageHandlers.fueg0.postMessage('playing');
                      }
                    },
                    onError: function() {
                      window.webkit.messageHandlers.fueg0.postMessage('error');
                    }
                  }
                });
              }
              window.fueg0Play = function() {
                if (player && player.playVideo) { player.playVideo(); }
              };
            </script>
            </body>
            </html>
            """
        }
    }
}

struct DailyFirePlayer: View {
    let video: DailyVideo?
    let failed: Bool
    let loading: Bool
    var onRetry: () -> Void

    @State private var showOverlay = true
    @State private var playNonce = 0
    @State private var playerFailed = false

    private var needsReload: Bool { failed || playerFailed || video == nil }

    var body: some View {
        ZStack {
            Palette.surfaceElevated

            if let video, !video.videoId.isEmpty {
                YouTubePlayerView(
                    videoId: video.videoId,
                    playNonce: playNonce,
                    onPlaying: {
                        playerFailed = false
                        showOverlay = false
                    },
                    onError: {
                        playerFailed = true
                        showOverlay = true
                    }
                )
                .id(video.videoId)
            }

            if loading && video == nil {
                ProgressView().tint(Palette.ember)
            } else if showOverlay || needsReload {
                overlay
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusLg, style: .continuous))
        .onChange(of: video?.videoId) { _, _ in
            showOverlay = true
            playerFailed = false
        }
        .task(id: video?.videoId) {
            try? await Task.sleep(for: .milliseconds(1600))
            if !Task.isCancelled, showOverlay, video != nil, !playerFailed {
                showOverlay = true
            }
        }
    }

    private var overlay: some View {
        Button {
            if needsReload {
                playerFailed = false
                onRetry()
            } else {
                playNonce += 1
            }
        } label: {
            ZStack {
                Color.black.opacity(0.72)
                VStack(spacing: Spacing.sm) {
                    Image(systemName: needsReload ? "arrow.clockwise" : "flame.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Palette.ember)
                    Text(needsReload ? "TAP TO RELOAD FIRE" : "TAP TO IGNITE")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Palette.textPrimary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
