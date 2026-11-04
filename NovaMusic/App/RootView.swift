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

                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(AppTab.search)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(AppTab.settings)
            }
            .safeAreaInset(edge: .bottom) {
                if appState.player.currentSong != nil {
                    MiniPlayerView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            if appState.importer.showsProgressSheet {
                ImportProgressOverlay()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(NovaTheme.Motion.gentle, value: appState.player.currentSong?.id)
        .animation(NovaTheme.Motion.standard, value: appState.importer.showsProgressSheet)
        .fullScreenCover(isPresented: $state.player.showsNowPlaying) {
            NowPlayingView()
                .environment(appState)
        }
        .onChange(of: appState.importer.isImporting) { _, isImporting in
            if !isImporting {
                appState.refreshAll()
            }
        }
    }
}
