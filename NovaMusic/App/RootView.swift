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

            if appState.importer.showsProgressSheet {
                ImportProgressOverlay()
                    .transition(.opacity)
                    .zIndex(2)
            }

            if appState.isResolvingYouTube {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView("Loading audio…")
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .zIndex(3)
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
        .alert(
            "YouTube",
            isPresented: Binding(
                get: { appState.youtubeResolveError != nil },
                set: { if !$0 { appState.youtubeResolveError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { appState.youtubeResolveError = nil }
        } message: {
            Text(appState.youtubeResolveError ?? "")
        }
        .onChange(of: appState.importer.isImporting) { _, isImporting in
            if !isImporting {
                appState.refreshAll()
            }
        }
        .onChange(of: appState.player.currentStream?.id) { _, id in
            if id == nil || appState.player.currentStream?.isYouTube != true {
                if !appState.isResolvingYouTube {
                    appState.youtubeNowPlaying = nil
                }
            }
        }
        .onChange(of: appState.player.currentSong?.id) { _, songID in
            if songID != nil {
                appState.youtubeNowPlaying = nil
            }
        }
    }
}
