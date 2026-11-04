import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class AppState {
    let persistence: PersistenceManager
    let library: MusicLibraryManager
    let importer: ImportManager
    let playlists: PlaylistManager
    let player: AudioPlayerManager
    let sleepTimer: SleepTimerManager

    var settings: AppSettings
    var searchHistory: [String]
    var selectedTab: AppTab = .home
    var librarySegment: LibrarySegment = .songs

    init() {
        let persistence = PersistenceManager.shared
        self.persistence = persistence
        self.library = MusicLibraryManager(persistence: persistence)
        self.importer = ImportManager(persistence: persistence)
        self.playlists = PlaylistManager(persistence: persistence)
        self.player = AudioPlayerManager(persistence: persistence)
        self.sleepTimer = SleepTimerManager()
        self.settings = persistence.loadSettings()
        self.searchHistory = persistence.loadSearchHistory()

        player.bind(library: library)
        sleepTimer.bind(player: player)

        library.refresh()
        playlists.refresh()
        player.restoreIfNeeded()
    }

    func refreshAll() {
        library.refresh()
        playlists.refresh()
    }

    func saveSettings() {
        persistence.saveSettings(settings)
        player.equalizerPreset = settings.equalizerPreset
    }

    func addSearchHistory(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var history = searchHistory.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        history.insert(trimmed, at: 0)
        if history.count > 20 { history = Array(history.prefix(20)) }
        searchHistory = history
        persistence.saveSearchHistory(history)
    }

    func clearSearchHistory() {
        searchHistory = []
        persistence.saveSearchHistory([])
    }

    var preferredColorScheme: ColorScheme? {
        settings.appearance.colorScheme
    }
}

enum AppTab: Hashable {
    case home
    case library
    case playlists
    case search
    case settings
}

enum LibrarySegment: String, CaseIterable, Identifiable {
    case songs
    case albums
    case artists
    case favorites
    case recent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .songs: return "Songs"
        case .albums: return "Albums"
        case .artists: return "Artists"
        case .favorites: return "Favorites"
        case .recent: return "Recent"
        }
    }
}
