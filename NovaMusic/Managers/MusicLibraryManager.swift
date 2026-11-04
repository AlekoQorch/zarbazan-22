import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class MusicLibraryManager {
    private(set) var songs: [Song] = []
    private(set) var isLoading = false

    var sort: PlaybackSort = .recentlyAdded
    var searchText: String = ""

    private let persistence: PersistenceManager

    init(persistence: PersistenceManager = .shared) {
        self.persistence = persistence
    }

    func refresh() {
        isLoading = true
        defer { isLoading = false }

        let descriptor = FetchDescriptor<Song>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        do {
            songs = try persistence.context.fetch(descriptor)
            validateMissingFiles()
        } catch {
            songs = []
            print("NovaMusic: library fetch failed — \(error)")
        }
    }

    private func validateMissingFiles() {
        for song in songs where !fileExists(for: song) {
            // Keep metadata; UI can show a missing-file badge. Do not auto-delete.
        }
    }

    func fileExists(for song: Song) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: song).path)
    }

    func fileURL(for song: Song) -> URL {
        FileStorage.absoluteURL(forRelativePath: song.relativeFilePath)
    }

    func artworkURL(for song: Song) -> URL? {
        guard let relative = song.artworkRelativePath else { return nil }
        let url = FileStorage.absoluteURL(forRelativePath: relative)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func song(id: UUID) -> Song? {
        songs.first { $0.id == id }
    }

    func songs(ids: [UUID]) -> [Song] {
        let map = Dictionary(uniqueKeysWithValues: songs.map { ($0.id, $0) })
        return ids.compactMap { map[$0] }
    }

    // MARK: - Queries

    var sortedSongs: [Song] {
        sortSongs(filteredSongs)
    }

    var filteredSongs: [Song] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return songs }
        return songs.filter {
            $0.title.localizedCaseInsensitiveContains(query)
            || $0.artist.localizedCaseInsensitiveContains(query)
            || $0.album.localizedCaseInsensitiveContains(query)
            || $0.genre.localizedCaseInsensitiveContains(query)
        }
    }

    func sortSongs(_ input: [Song]) -> [Song] {
        switch sort {
        case .title:
            return input.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .artist:
            return input.sorted {
                if $0.artist == $1.artist {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending
            }
        case .recentlyAdded:
            return input.sorted { $0.dateAdded > $1.dateAdded }
        case .recentlyPlayed:
            return input.sorted {
                ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast)
            }
        case .duration:
            return input.sorted { $0.duration < $1.duration }
        }
    }

    var recentlyAdded: [Song] {
        Array(songs.sorted { $0.dateAdded > $1.dateAdded }.prefix(20))
    }

    var recentlyPlayed: [Song] {
        Array(
            songs
                .filter { $0.lastPlayedAt != nil }
                .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
                .prefix(20)
        )
    }

    var favorites: [Song] {
        songs.filter(\.isFavorite).sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    var albums: [AlbumGroup] {
        let grouped = Dictionary(grouping: songs) { "\($0.album)|\($0.artist)" }
        return grouped.compactMap { _, songs in
            guard let first = songs.first else { return nil }
            let ordered = songs.sorted {
                if $0.trackNumber == $1.trackNumber {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.trackNumber < $1.trackNumber
            }
            return AlbumGroup(name: first.album, artist: first.artist, songs: ordered)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var artists: [ArtistGroup] {
        let grouped = Dictionary(grouping: songs, by: \.artist)
        return grouped.map { ArtistGroup(name: $0.key, songs: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var mostPlayed: [Song] {
        Array(songs.sorted { $0.playCount > $1.playCount }.filter { $0.playCount > 0 }.prefix(20))
    }

    var totalListeningTime: Double {
        songs.reduce(0) { $0 + (Double($1.playCount) * $1.duration) }
    }

    // MARK: - Mutations

    func toggleFavorite(_ song: Song) {
        song.isFavorite.toggle()
        persistence.save()
        refresh()
    }

    func updateMetadata(
        song: Song,
        title: String,
        artist: String,
        album: String,
        genre: String,
        trackNumber: Int,
        artworkData: Data?
    ) {
        song.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown Title" : title
        song.artist = artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown Artist" : artist
        song.album = album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown Album" : album
        song.genre = genre
        song.trackNumber = trackNumber

        if let artworkData,
           let jpeg = MetadataExtractor.downsampleArtwork(artworkData) {
            let artName = "\(song.fileHash.prefix(16))-edit.jpg"
            let artURL = FileStorage.artworkFileURL(fileName: artName)
            try? jpeg.write(to: artURL, options: [.atomic])
            if let old = song.artworkRelativePath {
                FileStorage.deleteIfExists(FileStorage.absoluteURL(forRelativePath: old))
            }
            song.artworkRelativePath = FileStorage.relativePath(from: artURL)
        }

        persistence.save()
        refresh()
    }

    func deleteSongs(_ songsToDelete: [Song]) {
        for song in songsToDelete {
            // Remove audio + artwork files
            FileStorage.deleteIfExists(fileURL(for: song))
            if let art = song.artworkRelativePath {
                FileStorage.deleteIfExists(FileStorage.absoluteURL(forRelativePath: art))
            }
            // Cascade nullify playlist items via relationship delete rule
            if let items = song.playlistItems {
                for item in items {
                    persistence.context.delete(item)
                }
            }
            persistence.context.delete(song)
        }
        persistence.save()
        refresh()
    }

    func recordPlay(for song: Song) {
        song.playCount += 1
        song.lastPlayedAt = Date()
        persistence.save()
    }

    func album(named name: String, artist: String) -> AlbumGroup? {
        albums.first { $0.name == name && $0.artist == artist }
    }
}
