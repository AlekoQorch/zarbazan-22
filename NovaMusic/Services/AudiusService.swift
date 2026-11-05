import Foundation

struct StreamTrack: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let artist: String
    let duration: Double
    let artworkURL: URL?
    let genre: String
    /// When set (YouTube audio / HLS), plays this URL instead of the Audius stream.
    let streamURLOverride: URL?

    init(
        id: String,
        title: String,
        artist: String,
        duration: Double,
        artworkURL: URL?,
        genre: String,
        streamURLOverride: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.artworkURL = artworkURL
        self.genre = genre
        self.streamURLOverride = streamURLOverride
    }

    var streamURL: URL {
        if let streamURLOverride { return streamURLOverride }
        return URL(string: "https://api.audius.co/v1/tracks/\(id)/stream?app_name=NovaMusic")!
    }

    var isYouTube: Bool { id.hasPrefix("yt-") || genre == "YouTube" }
}

enum AudiusService {
    private static let appName = "NovaMusic"
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.httpAdditionalHeaders = [
            "User-Agent": "NovaMusic/1.0 (iOS)",
            "Accept": "application/json"
        ]
        return URLSession(configuration: config)
    }()

    static func search(query: String) async throws -> [StreamTrack] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        var components = URLComponents(string: "https://api.audius.co/v1/tracks/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "app_name", value: appName)
        ]
        return try await fetchTracks(from: components.url)
    }

    static func trending(limit: Int = 20) async throws -> [StreamTrack] {
        var components = URLComponents(string: "https://api.audius.co/v1/tracks/trending")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "app_name", value: appName)
        ]
        return try await fetchTracks(from: components.url)
    }

    private static func fetchTracks(from url: URL?) async throws -> [StreamTrack] {
        guard let url else { return [] }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(AudiusSearchResponse.self, from: data)
        return decoded.data.compactMap(mapTrack)
    }

    private static func mapTrack(_ item: AudiusTrackDTO) -> StreamTrack? {
        guard item.access?.stream != false else { return nil }
        let art = item.artwork?.url480 ?? item.artwork?.url150
        return StreamTrack(
            id: item.id,
            title: item.title,
            artist: item.user?.name ?? "Unknown Artist",
            duration: Double(item.duration ?? 0),
            artworkURL: art.flatMap(URL.init(string:)),
            genre: item.genre ?? ""
        )
    }
}

private struct AudiusSearchResponse: Decodable {
    let data: [AudiusTrackDTO]
}

private struct AudiusTrackDTO: Decodable {
    let id: String
    let title: String
    let duration: Int?
    let genre: String?
    let artwork: AudiusArtworkDTO?
    let user: AudiusUserDTO?
    let access: AudiusAccessDTO?
}

private struct AudiusArtworkDTO: Decodable {
    let url150: String?
    let url480: String?
    let url1000: String?

    enum CodingKeys: String, CodingKey {
        case url150 = "150x150"
        case url480 = "480x480"
        case url1000 = "1000x1000"
    }
}

private struct AudiusUserDTO: Decodable {
    let name: String?
}

private struct AudiusAccessDTO: Decodable {
    let stream: Bool?
    let download: Bool?
}
