import Foundation

struct YouTubeVideo: Identifiable, Hashable, Codable, Sendable {
    /// YouTube video id (e.g. `dQw4w9WgXcQ`).
    let id: String
    let title: String
    let channelTitle: String
    let thumbnailURL: URL?
    let publishedAt: Date?
    var durationSeconds: Double?

    var durationText: String {
        guard let durationSeconds, durationSeconds > 0 else { return "—" }
        return DurationFormatter.string(from: durationSeconds)
    }

    var embedURL: URL {
        var components = URLComponents(string: "https://www.youtube-nocookie.com/embed/\(id)")!
        components.queryItems = [
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "rel", value: "0"),
            URLQueryItem(name: "modestbranding", value: "1"),
            URLQueryItem(name: "autoplay", value: "1"),
            URLQueryItem(name: "enablejsapi", value: "1")
        ]
        return components.url!
    }
}

struct YouTubePlaylist: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var name: String
    var videos: [YouTubeVideo]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        videos: [YouTubeVideo] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.videos = videos
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
