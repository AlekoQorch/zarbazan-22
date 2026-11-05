import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        ZStack(alignment: .bottom) {
            TabView(selection: $state.selectedTab) {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(AppTab.home)

                LibraryView()
                    .tabItem { Label("Library", systemImage: "music.note.list") }
                    .tag(AppTab.library)

                PlaylistsView()
                    .tabItem { Label("Playlists", systemImage: "rectangle.stack.fill") }
                    .tag(AppTab.playlists)

                ExploreView()
                    .tabItem { Label("Explore", systemImage: "safari.fill") }
                    .tag(AppTab.search)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(AppTab.settings)
            }
            .safeAreaInset(edge: .bottom) {
                if appState.hasMiniPlayer {
                    MiniPlayerView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Keep YouTube embed mounted while a video is "now playing",
            // even after the full-screen UI is dismissed (minimize).
            if let video = appState.youtubeNowPlaying, !appState.showsYouTubePlayer {
                YouTubeEmbedWebView(videoID: video.id)
                    .frame(width: 220, height: 124)
                    .opacity(0.02)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 8)
                    .padding(.bottom, 100)
            }

            if appState.importer.showsProgressSheet {
                ImportProgressOverlay()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(NovaTheme.Motion.gentle, value: appState.player.currentSong?.id)
        .animation(NovaTheme.Motion.gentle, value: appState.player.currentStream?.id)
        .animation(NovaTheme.Motion.gentle, value: appState.youtubeNowPlaying?.id)
        .animation(NovaTheme.Motion.standard, value: appState.importer.showsProgressSheet)
        .fullScreenCover(isPresented: $state.player.showsNowPlaying) {
            NowPlayingView()
                .environment(appState)
        }
        .fullScreenCover(isPresented: $state.showsYouTubePlayer) {
            if let video = appState.youtubeNowPlaying {
                YouTubePlayerView(video: video) {
                    appState.dismissYouTubePlayer()
                }
                .environment(appState)
            }
        }
        .onChange(of: appState.importer.isImporting) { _, isImporting in
            if !isImporting {
                appState.refreshAll()
            }
        }
    }
}
