import Foundation
import SwiftData

@Model
final class Playlist: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var lastPlayedAt: Date?
    var artworkSongID: UUID?

    @Relationship(deleteRule: .cascade, inverse: \PlaylistItem.playlist)
    var items: [PlaylistItem]?

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastPlayedAt: Date? = nil,
        artworkSongID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastPlayedAt = lastPlayedAt
        self.artworkSongID = artworkSongID
        self.items = []
    }

    var orderedItems: [PlaylistItem] {
        (items ?? []).sorted { $0.position < $1.position }
    }

    var songs: [Song] {
        orderedItems.compactMap(\.song)
    }

    var songCount: Int {
        songs.count
    }

    var totalDuration: Double {
        songs.reduce(0) { $0 + $1.duration }
    }
}

@Model
final class PlaylistItem: Identifiable {
    @Attribute(.unique) var id: UUID
    var position: Int
    var addedAt: Date

    var playlist: Playlist?
    var song: Song?

    init(
        id: UUID = UUID(),
        position: Int,
        addedAt: Date = Date(),
        playlist: Playlist? = nil,
        song: Song? = nil
    ) {
        self.id = id
        self.position = position
        self.addedAt = addedAt
        self.playlist = playlist
        self.song = song
    }
}
