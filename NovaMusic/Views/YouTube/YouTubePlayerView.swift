import SwiftUI
import WebKit

/// Official YouTube IFrame / embed player hosted in WKWebView.
struct YouTubePlayerView: View {
    let video: YouTubeVideo
    var onClose: (() -> Void)?

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showAddToPlaylist = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                YouTubeEmbedWebView(videoID: video.id)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, NovaTheme.Spacing.md)
                    .padding(.top, NovaTheme.Spacing.md)

                VStack(alignment: .leading, spacing: 8) {
                    Text(video.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.novaTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(video.channelTitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.novaTextSecondary)
                    HStack(spacing: 12) {
                        Label(video.durationText, systemImage: "clock")
                        Text("YouTube · Embedded")
                            .foregroundStyle(Color.novaTextSecondary)
                    }
                    .font(.caption)
                    .foregroundStyle(Color.novaTextSecondary)

                    Text("Minimize keeps playing. Lock-screen continue is best-effort for embeds.")
                        .font(.caption2)
                        .foregroundStyle(Color.novaTextSecondary.opacity(0.85))
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(NovaTheme.Spacing.md)

                HStack(spacing: NovaTheme.Spacing.md) {
                    Button {
                        _ = appState.youtube.toggleFavorite(video)
                    } label: {
                        Label(
                            appState.youtube.isFavorite(video) ? "Favorited" : "Favorite",
                            systemImage: appState.youtube.isFavorite(video) ? "heart.fill" : "heart"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.novaAccent)

                    Button {
                        showAddToPlaylist = true
                    } label: {
                        Label("Playlist", systemImage: "text.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, NovaTheme.Spacing.md)

                Spacer(minLength: 0)
            }
            .novaScreen()
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Minimize") {
                        BackgroundPlaybackKeeper.shared.setWantPlaying(true)
                        BackgroundPlaybackKeeper.shared.forceResume()
                        onClose?()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Stop", role: .destructive) {
                        appState.stopYouTube()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddToPlaylist) {
                AddToYouTubePlaylistSheet(video: video)
                    .environment(appState)
                    .presentationDetents([.medium, .large])
            }
            .onAppear {
                appState.player.pause()
                BackgroundPlaybackKeeper.shared.setWantPlaying(true)
            }
        }
    }
}

struct YouTubeEmbedWebView: UIViewRepresentable {
    let videoID: String

    func makeCoordinator() -> Coordinator {
        Coordinator(videoID: videoID)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        if #available(iOS 15.4, *) {
            config.preferences.isElementFullscreenEnabled = true
        }
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        BackgroundPlaybackKeeper.shared.bindYouTubeWebView(webView)
        BackgroundPlaybackKeeper.shared.activateSession()
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        BackgroundPlaybackKeeper.shared.bindYouTubeWebView(webView)
        guard context.coordinator.loadedID != videoID else {
            context.coordinator.resumeIfNeeded()
            return
        }
        context.coordinator.loadedID = videoID
        context.coordinator.videoID = videoID
        let html = Self.embedHTML(videoID: videoID)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube-nocookie.com")!)
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        if BackgroundPlaybackKeeper.shared.youtubeWebView === uiView {
            BackgroundPlaybackKeeper.shared.bindYouTubeWebView(nil)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedID: String?
        var videoID: String
        weak var webView: WKWebView?
        private var resumeObserver: NSObjectProtocol?

        init(videoID: String) {
            self.videoID = videoID
            super.init()
            resumeObserver = NotificationCenter.default.addObserver(
                forName: .novaForceResumePlayback,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.resumeIfNeeded()
            }
        }

        deinit {
            if let resumeObserver {
                NotificationCenter.default.removeObserver(resumeObserver)
            }
        }

        func resumeIfNeeded() {
            let js = """
            (function(){
              try {
                if (typeof player !== 'undefined' && player && player.playVideo) {
                  player.playVideo();
                }
              } catch (e) {}
              true;
            })();
            """
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            resumeIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.resumeIfNeeded() }
        }
    }

    /// Official IFrame Player API bootstrap with auto-resume on pause.
    private static func embedHTML(videoID: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
          <style>
            html, body { margin:0; padding:0; background:#000; height:100%; overflow:hidden; }
            #player { position:absolute; inset:0; }
          </style>
        </head>
        <body>
          <div id="player"></div>
          <script src="https://www.youtube.com/iframe_api"></script>
          <script>
            var player;
            var wantPlay = true;
            function onYouTubeIframeAPIReady() {
              player = new YT.Player('player', {
                height: '100%',
                width: '100%',
                videoId: '\(videoID)',
                playerVars: {
                  playsinline: 1,
                  rel: 0,
                  modestbranding: 1,
                  autoplay: 1,
                  fs: 1,
                  origin: 'https://www.youtube-nocookie.com'
                },
                events: {
                  onReady: function() { try { player.playVideo(); } catch(e) {} },
                  onStateChange: function(e) {
                    // 2 = paused — if we still want audio, resume (fold/lock often triggers this)
                    if (wantPlay && e.data === 2) {
                      setTimeout(function(){ try { player.playVideo(); } catch(err) {} }, 120);
                      setTimeout(function(){ try { player.playVideo(); } catch(err) {} }, 500);
                    }
                  }
                }
              });
            }
            document.addEventListener('visibilitychange', function() {
              if (wantPlay) {
                try { player && player.playVideo && player.playVideo(); } catch(e) {}
              }
            });
            setInterval(function(){
              if (!wantPlay || !player || !player.getPlayerState) return;
              try {
                var s = player.getPlayerState();
                if (s === 2 || s === -1) player.playVideo();
              } catch(e) {}
            }, 1000);
          </script>
        </body>
        </html>
        """
    }
}
