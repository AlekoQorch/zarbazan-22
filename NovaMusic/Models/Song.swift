import Foundation
import SwiftData

@Model
final class Song: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var artist: String
    var album: String
    var genre: String
    var trackNumber: Int
    var duration: Double
    var relativeFilePath: String
    var artworkRelativePath: String?
    var fileHash: String
    var fileSize: Int64
    var fileExtension: String
    var dateAdded: Date
    var lastPlayedAt: Date?
    var playCount: Int
    var isFavorite: Bool
    var bookmarkData: Data?

    @Relationship(deleteRule: .nullify, inverse: \PlaylistItem.song)
    var playlistItems: [PlaylistItem]?

    init(
        id: UUID = UUID(),
        title: String,
        artist: String = "Unknown Artist",
        album: String = "Unknown Album",
        genre: String = "",
        trackNumber: Int = 0,
        duration: Double = 0,
        relativeFilePath: String,
        artworkRelativePath: String? = nil,
        fileHash: String,
        fileSize: Int64 = 0,
        fileExtension: String = "",
        dateAdded: Date = Date(),
        lastPlayedAt: Date? = nil,
        playCount: Int = 0,
        isFavorite: Bool = false,
        bookmarkData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.genre = genre
        self.trackNumber = trackNumber
        self.duration = duration
        self.relativeFilePath = relativeFilePath
        self.artworkRelativePath = artworkRelativePath
        self.fileHash = fileHash
        self.fileSize = fileSize
        self.fileExtension = fileExtension
        self.dateAdded = dateAdded
        self.lastPlayedAt = lastPlayedAt
        self.playCount = playCount
        self.isFavorite = isFavorite
        self.bookmarkData = bookmarkData
        self.playlistItems = []
    }

    var formattedDuration: String {
        DurationFormatter.string(from: duration)
    }

    var displayArtistAlbum: String {
        "\(artist) · \(album)"
    }
}
