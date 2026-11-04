import Foundation
import SwiftData

@MainActor
@Observable
final class PlaylistManager {
    private(set) var playlists: [Playlist] = []

    private let persistence: PersistenceManager

    init(persistence: PersistenceManager = .shared) {
        self.persistence = persistence
    }

    func refresh() {
        let descriptor = FetchDescriptor<Playlist>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        playlists = (try? persistence.context.fetch(descriptor)) ?? []
    }

    var recentlyPlayedPlaylists: [Playlist] {
        playlists
            .filter { $0.lastPlayedAt != nil }
            .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
    }

    func createPlaylist(named name: String, songs: [Song] = []) -> Playlist {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let playlist = Playlist(name: trimmed.isEmpty ? "New Playlist" : trimmed)
        persistence.context.insert(playlist)
        for (index, song) in songs.enumerated() {
            let item = PlaylistItem(position: index, playlist: playlist, song: song)
            persistence.context.insert(item)
        }
        if let first = songs.first {
            playlist.artworkSongID = first.id
        }
        persistence.save()
        refresh()
        return playlist
    }

    func rename(_ playlist: Playlist, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        playlist.name = trimmed
        playlist.updatedAt = Date()
        persistence.save()
        refresh()
    }

    func delete(_ playlist: Playlist) {
        persistence.context.delete(playlist)
        persistence.save()
        refresh()
    }

    func add(songs: [Song], to playlist: Playlist) {
        let existingIDs = Set(playlist.songs.map(\.id))
        var position = playlist.songCount
        for song in songs where !existingIDs.contains(song.id) {
            let item = PlaylistItem(position: position, playlist: playlist, song: song)
            persistence.context.insert(item)
            position += 1
        }
        if playlist.artworkSongID == nil {
            playlist.artworkSongID = songs.first?.id
        }
        playlist.updatedAt = Date()
        persistence.save()
        refresh()
    }

    func remove(songs: [Song], from playlist: Playlist) {
        let ids = Set(songs.map(\.id))
        for item in playlist.orderedItems where item.song.map({ ids.contains($0.id) }) == true {
            persistence.context.delete(item)
        }
        reindex(playlist)
        playlist.updatedAt = Date()
        persistence.save()
        refresh()
    }

    func moveSong(in playlist: Playlist, fromOffsets: IndexSet, toOffset: Int) {
        var ordered = playlist.orderedItems
        ordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (index, item) in ordered.enumerated() {
            item.position = index
        }
        playlist.updatedAt = Date()
        persistence.save()
        refresh()
    }

    func markPlayed(_ playlist: Playlist) {
        playlist.lastPlayedAt = Date()
        persistence.save()
        refresh()
    }

    private func reindex(_ playlist: Playlist) {
        for (index, item) in playlist.orderedItems.enumerated() {
            item.position = index
        }
    }
}
