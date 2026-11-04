import Foundation

/// Favorites + custom playlists for YouTube videos (local persistence only).
@MainActor
@Observable
final class YouTubeLibraryManager {
    private(set) var favorites: [YouTubeVideo] = []
    private(set) var playlists: [YouTubePlaylist] = []

    private let favoritesKey = "nova.youtube.favorites"
    private let playlistsKey = "nova.youtube.playlists"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        reload()
    }

    func reload() {
        favorites = load([YouTubeVideo].self, key: favoritesKey) ?? []
        playlists = load([YouTubePlaylist].self, key: playlistsKey) ?? []
    }

    func isFavorite(_ video: YouTubeVideo) -> Bool {
        favorites.contains { $0.id == video.id }
    }

    @discardableResult
    func toggleFavorite(_ video: YouTubeVideo) -> Bool {
        if let idx = favorites.firstIndex(where: { $0.id == video.id }) {
            favorites.remove(at: idx)
            persistFavorites()
            return false
        } else {
            favorites.insert(video, at: 0)
            persistFavorites()
            return true
        }
    }

    func createPlaylist(named name: String) -> YouTubePlaylist? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let playlist = YouTubePlaylist(name: trimmed)
        playlists.insert(playlist, at: 0)
        persistPlaylists()
        return playlist
    }

    func renamePlaylist(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[idx].name = trimmed
        playlists[idx].updatedAt = Date()
        persistPlaylists()
    }

    func deletePlaylist(_ id: UUID) {
        playlists.removeAll { $0.id == id }
        persistPlaylists()
    }

    func add(_ video: YouTubeVideo, toPlaylist id: UUID) {
        guard let idx = playlists.firstIndex(where: { $0.id == id }) else { return }
        if playlists[idx].videos.contains(where: { $0.id == video.id }) { return }
        playlists[idx].videos.append(video)
        playlists[idx].updatedAt = Date()
        persistPlaylists()
    }

    func removeVideo(id videoID: String, fromPlaylist playlistID: UUID) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[idx].videos.removeAll { $0.id == videoID }
        playlists[idx].updatedAt = Date()
        persistPlaylists()
    }

    private func persistFavorites() {
        save(favorites, key: favoritesKey)
    }

    private func persistPlaylists() {
        save(playlists, key: playlistsKey)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? encoder.encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}
