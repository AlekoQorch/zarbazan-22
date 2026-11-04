import Foundation

enum RepeatMode: String, CaseIterable, Codable {
    case off
    case all
    case one

    var systemImage: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}

enum PlaybackSort: String, CaseIterable, Identifiable {
    case title
    case artist
    case recentlyAdded
    case recentlyPlayed
    case duration

    var id: String { rawValue }

    var label: String {
        switch self {
        case .title: return "Title"
        case .artist: return "Artist"
        case .recentlyAdded: return "Recently Added"
        case .recentlyPlayed: return "Recently Played"
        case .duration: return "Duration"
        }
    }
}

enum EqualizerPreset: String, CaseIterable, Identifiable, Codable {
    case off
    case balanced
    case bassBoost
    case treble
    case classical
    case vocal
    case electronic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .balanced: return "Balanced"
        case .bassBoost: return "Bass Boost"
        case .treble: return "Treble"
        case .classical: return "Classical"
        case .vocal: return "Vocal"
        case .electronic: return "Electronic"
        }
    }

    /// Gain values in dB for bands: 32, 64, 125, 250, 500, 1k, 2k, 4k, 8k, 16k
    var gains: [Float] {
        switch self {
        case .off, .balanced:
            return Array(repeating: 0, count: 10)
        case .bassBoost:
            return [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]
        case .treble:
            return [0, 0, 0, 0, 0, 1, 2, 4, 5, 6]
        case .classical:
            return [4, 3, 2, 0, -1, 0, 2, 3, 3, 2]
        case .vocal:
            return [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1]
        case .electronic:
            return [5, 4, 2, 0, -2, 0, 2, 3, 4, 5]
        }
    }
}

enum SleepTimerOption: Identifiable, Hashable {
    case minutes(Int)
    case endOfTrack

    var id: String {
        switch self {
        case .minutes(let m): return "m\(m)"
        case .endOfTrack: return "eot"
        }
    }

    var title: String {
        switch self {
        case .minutes(let m) where m < 60:
            return "\(m) min"
        case .minutes(let m):
            return "\(m / 60) hr"
        case .endOfTrack:
            return "End of Track"
        }
    }

    static let presets: [SleepTimerOption] = [
        .minutes(5), .minutes(15), .minutes(30), .minutes(45), .minutes(60), .minutes(90), .endOfTrack
    ]
}

struct QueueEntry: Identifiable, Equatable, Hashable {
    let id: UUID
    let songID: UUID

    init(id: UUID = UUID(), songID: UUID) {
        self.id = id
        self.songID = songID
    }
}

struct PlaybackSnapshot: Codable, Equatable {
    var currentSongID: UUID?
    var position: Double
    var wasPlaying: Bool
    var queueSongIDs: [UUID]
    var queueIndex: Int
    var shuffleEnabled: Bool
    var repeatMode: RepeatMode
    var shuffleOrder: [UUID]

    static let empty = PlaybackSnapshot(
        currentSongID: nil,
        position: 0,
        wasPlaying: false,
        queueSongIDs: [],
        queueIndex: 0,
        shuffleEnabled: false,
        repeatMode: .off,
        shuffleOrder: []
    )
}

struct ImportProgress: Equatable {
    var total: Int
    var completed: Int
    var currentFileName: String
    var succeeded: Int
    var failed: Int
    var skippedDuplicates: Int
    var errors: [ImportFileError]

    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    static let idle = ImportProgress(
        total: 0, completed: 0, currentFileName: "",
        succeeded: 0, failed: 0, skippedDuplicates: 0, errors: []
    )
}

struct ImportFileError: Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let message: String

    init(id: UUID = UUID(), fileName: String, message: String) {
        self.id = id
        self.fileName = fileName
        self.message = message
    }
}

struct AlbumGroup: Identifiable {
    var id: String { "\(artist)|\(name)" }
    let name: String
    let artist: String
    let songs: [Song]
    var artworkSong: Song? { songs.first }
    var totalDuration: Double { songs.reduce(0) { $0 + $1.duration } }
}

struct ArtistGroup: Identifiable {
    var id: String { name }
    let name: String
    let songs: [Song]
    var albumCount: Int {
        Set(songs.map(\.album)).count
    }
}
