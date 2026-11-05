import SwiftUI
import SwiftData

@main
struct NovaMusicApp: App {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .modelContainer(appState.persistence.container)
                .preferredColorScheme(appState.preferredColorScheme)
                .tint(Color.novaAccent)
                .onAppear {
                    BackgroundPlaybackKeeper.shared.activateSession()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background || phase == .inactive {
                        if appState.youtubeNowPlaying != nil || appState.player.isPlaying {
                            BackgroundPlaybackKeeper.shared.setWantPlaying(true)
                            BackgroundPlaybackKeeper.shared.forceResume()
                        }
                    } else if phase == .active {
                        BackgroundPlaybackKeeper.shared.forceResume()
                        if appState.player.hasSomethingToPlay, !appState.player.isPlaying,
                           BackgroundPlaybackKeeper.shared.wantPlaying {
                            appState.player.play()
                        }
                    }
                }
        }
    }
}
