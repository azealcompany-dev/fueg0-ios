import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    var videoID: String
    var onPlaying: (String) -> Void
    var onUnplayable: (String, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPlaying: onPlaying, onUnplayable: onUnplayable)
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
        context.coordinator.load(videoID: videoID)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onPlaying = onPlaying
        context.coordinator.onUnplayable = onUnplayable
        if context.coordinator.loadedID != videoID {
            context.coordinator.load(videoID: videoID)
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.invalidate()
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "fueg0")
        uiView.navigationDelegate = nil
        uiView.stopLoading()
        coordinator.webView = nil
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var onPlaying: (String) -> Void
        var onUnplayable: (String, String) -> Void
        weak var webView: WKWebView?
        var loadedID = ""
        private var failed = false
        private var timeout: DispatchWorkItem?
        private let origin = YouTubeEmbed.origin(bundleID: Bundle.main.bundleIdentifier)

        init(onPlaying: @escaping (String) -> Void, onUnplayable: @escaping (String, String) -> Void) {
            self.onPlaying = onPlaying
            self.onUnplayable = onUnplayable
        }

        func load(videoID: String) {
            failed = false
            loadedID = videoID
            timeout?.cancel()
            guard let html = YouTubeEmbed.html(videoID: videoID, origin: origin),
                  let baseURL = URL(string: origin) else {
                fail(code: "2")
                return
            }
            let work = DispatchWorkItem { [weak self] in
                self?.fail(code: "timeout")
            }
            timeout = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 18, execute: work)
            webView?.loadHTMLString(html, baseURL: baseURL)
        }

        func invalidate() {
            failed = true
            timeout?.cancel()
            timeout = nil
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            let body = (message.body as? String) ?? ""
            if body == "ready" {
                timeout?.cancel()
            } else if body == "playing" {
                timeout?.cancel()
                let id = loadedID
                let callback = onPlaying
                DispatchQueue.main.async { callback(id) }
            } else if body.hasPrefix("error") {
                let code = body.split(separator: ":", maxSplits: 1).dropFirst().first.map(String.init) ?? "unknown"
                fail(code: code)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            fail(code: "network")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            fail(code: "network")
        }

        private func fail(code: String) {
            guard !failed else { return }
            failed = true
            timeout?.cancel()
            let id = loadedID
            let callback = onUnplayable
            DispatchQueue.main.async { callback(id, code) }
        }
    }
}

struct DailyFirePlayer: View {
    let video: DailyVideo?
    let failed: Bool
    let loading: Bool
    var failureMessage: String
    var onRetry: () -> Void
    var onPlaying: (String) -> Void
    var onUnplayable: (String, String) -> Void

    var body: some View {
        ZStack {
            Palette.surfaceElevated
            if loading {
                ProgressView()
                    .tint(Palette.ember)
                    .accessibilityLabel("Loading motivational videos")
            } else if let video, !failed, DailyFireID.isPlayable(video.videoId) {
                YouTubePlayerView(
                    videoID: video.videoId,
                    onPlaying: onPlaying,
                    onUnplayable: onUnplayable
                )
                .id(video.videoId)
                .accessibilityLabel(video.title)
            } else {
                failure
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(.horizontal, -Spacing.screen)
    }

    private var failure: some View {
        Button(action: onRetry) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "flame")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Palette.ember)
                Text(failureMessage)
                    .font(.system(size: 15, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.textPrimary)
                Text("TAP TO RETRY")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Palette.ember)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(failureMessage) Tap to retry.")
    }
}
