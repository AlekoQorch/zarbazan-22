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
    let youtube: YouTubeLibraryManager

    var settings: AppSettings
    var searchHistory: [String]
    var selectedTab: AppTab = .home
    var librarySegment: LibrarySegment = .songs
    /// YouTube search works without a Google key (Piped fallback).
    var exploreSegment: ExploreSegment = .youtube
    /// Metadata for the YouTube track currently resolved into AVPlayer.
    var youtubeNowPlaying: YouTubeVideo?
    var isResolvingYouTube = false
    var youtubeResolveError: String?

    var hasMiniPlayer: Bool {
        player.hasSomethingToPlay || youtubeNowPlaying != nil
    }

    func playYouTube(_ video: YouTubeVideo) {
        youtubeResolveError = nil
        isResolvingYouTube = true
        youtubeNowPlaying = video
        player.pause()
        Task { @MainActor in
            defer { isResolvingYouTube = false }
            do {
                let url = try await YouTubeService.resolvePlaybackURL(videoID: video.id)
                let track = YouTubeService.streamTrack(for: video, url: url)
                player.playStream(track)
                player.showsNowPlaying = true
                BackgroundPlaybackKeeper.shared.setWantPlaying(true)
            } catch {
                youtubeResolveError = error.localizedDescription
                youtubeNowPlaying = nil
                BackgroundPlaybackKeeper.shared.setWantPlaying(false)
            }
        }
    }

    func stopYouTube() {
        youtubeNowPlaying = nil
        youtubeResolveError = nil
        isResolvingYouTube = false
        if player.currentStream?.isYouTube == true {
            player.stop()
        }
        BackgroundPlaybackKeeper.shared.setWantPlaying(false)
    }

    init() {
        let persistence = PersistenceManager.shared
        self.persistence = persistence
        self.library = MusicLibraryManager(persistence: persistence)
        self.importer = ImportManager(persistence: persistence)
        self.playlists = PlaylistManager(persistence: persistence)
        self.player = AudioPlayerManager(persistence: persistence)
        self.sleepTimer = SleepTimerManager()
        self.youtube = YouTubeLibraryManager()
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
    /// Explore tab (YouTube + streaming + library). Tag kept as `search` for stability.
    case search
    case settings
}

enum ExploreSegment: String, CaseIterable, Identifiable {
    case youtube
    case streaming
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .youtube: return "YouTube"
        case .streaming: return "Free"
        case .library: return "Library"
        }
    }
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
