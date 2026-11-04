import SwiftUI
import SwiftData

@main
struct NovaMusicApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .modelContainer(appState.persistence.container)
                .preferredColorScheme(appState.preferredColorScheme)
                .tint(Color.novaAccent)
        }
    }
}
