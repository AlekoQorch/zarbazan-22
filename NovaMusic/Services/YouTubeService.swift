import Foundation

enum YouTubeServiceError: LocalizedError {
    case missingAPIKey
    case invalidQuery
    case badResponse(Int)
    case decoding
    case apiMessage(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add a YouTube Data API v3 key in Settings → YouTube."
        case .invalidQuery:
            return "Enter at least 2 characters to search."
        case .badResponse(let code):
            return "YouTube API error (HTTP \(code))."
        case .decoding:
            return "Couldn’t read YouTube search results."
        case .apiMessage(let message):
            return message
        }
    }
}

/// Official YouTube Data API v3 client (search + video details). No scraping.
enum YouTubeService {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": "NovaMusic/1.0 (iOS; YouTubeDataAPI)"
        ]
        return URLSession(configuration: config)
    }()

    /// Search embeddable videos. Biases toward music with `videoCategoryId=10` when supported;
    /// always requires `type=video` + `videoEmbeddable=true`.
    static func search(query: String, maxResults: Int = 25) async throws -> [YouTubeVideo] {
        guard let apiKey = YouTubeConfig.apiKey else { throw YouTubeServiceError.missingAPIKey }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { throw YouTubeServiceError.invalidQuery }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "videoEmbeddable", value: "true"),
            URLQueryItem(name: "videoCategoryId", value: "10"),
            URLQueryItem(name: "maxResults", value: String(min(max(1, maxResults), 50))),
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "key", value: apiKey)
        ]

        let data = try await getData(from: components.url)
        let decoded: YTSearchResponse
        do {
            decoded = try JSONDecoder.youtube.decode(YTSearchResponse.self, from: data)
        } catch {
            throw YouTubeServiceError.decoding
        }

        if let error = decoded.error {
            throw YouTubeServiceError.apiMessage(error.message ?? "YouTube API rejected the request.")
        }

        var videos: [YouTubeVideo] = decoded.items?.compactMap { item in
            guard let id = item.id?.videoId,
                  let snippet = item.snippet else { return nil }
            let thumb = snippet.thumbnails?.high?.url
                ?? snippet.thumbnails?.medium?.url
                ?? snippet.thumbnails?.default?.url
            return YouTubeVideo(
                id: id,
                title: snippet.title ?? "Untitled",
                channelTitle: snippet.channelTitle ?? "YouTube",
                thumbnailURL: thumb.flatMap(URL.init(string:)),
                publishedAt: snippet.publishedAt,
                durationSeconds: nil
            )
        } ?? []

        // Category filter can be overly strict for some queries — retry without it if empty.
        if videos.isEmpty {
            videos = try await searchUncategorized(query: trimmed, maxResults: maxResults, apiKey: apiKey)
        }

        let ids = videos.map(\.id)
        let durations = try await fetchDurations(videoIDs: ids, apiKey: apiKey)
        for i in videos.indices {
            videos[i].durationSeconds = durations[videos[i].id]
        }
        return videos
    }

    private static func searchUncategorized(query: String, maxResults: Int, apiKey: String) async throws -> [YouTubeVideo] {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "videoEmbeddable", value: "true"),
            URLQueryItem(name: "maxResults", value: String(min(max(1, maxResults), 50))),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "key", value: apiKey)
        ]
        let data = try await getData(from: components.url)
        let decoded = try JSONDecoder.youtube.decode(YTSearchResponse.self, from: data)
        if let error = decoded.error {
            throw YouTubeServiceError.apiMessage(error.message ?? "YouTube API rejected the request.")
        }
        return decoded.items?.compactMap { item in
            guard let id = item.id?.videoId, let snippet = item.snippet else { return nil }
            let thumb = snippet.thumbnails?.high?.url
                ?? snippet.thumbnails?.medium?.url
                ?? snippet.thumbnails?.default?.url
            return YouTubeVideo(
                id: id,
                title: snippet.title ?? "Untitled",
                channelTitle: snippet.channelTitle ?? "YouTube",
                thumbnailURL: thumb.flatMap(URL.init(string:)),
                publishedAt: snippet.publishedAt,
                durationSeconds: nil
            )
        } ?? []
    }

    static func fetchDurations(videoIDs: [String], apiKey: String? = YouTubeConfig.apiKey) async throws -> [String: Double] {
        guard let apiKey else { throw YouTubeServiceError.missingAPIKey }
        let unique = Array(Set(videoIDs.filter { !$0.isEmpty }))
        guard !unique.isEmpty else { return [:] }

        var result: [String: Double] = [:]
        // videos.list allows up to 50 ids per request
        for chunk in unique.chunked(into: 50) {
            var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")!
            components.queryItems = [
                URLQueryItem(name: "part", value: "contentDetails"),
                URLQueryItem(name: "id", value: chunk.joined(separator: ",")),
                URLQueryItem(name: "key", value: apiKey)
            ]
            let data = try await getData(from: components.url)
            let decoded = try JSONDecoder.youtube.decode(YTVideosResponse.self, from: data)
            if let error = decoded.error {
                throw YouTubeServiceError.apiMessage(error.message ?? "YouTube API rejected the request.")
            }
            for item in decoded.items ?? [] {
                guard let id = item.id, let iso = item.contentDetails?.duration else { continue }
                result[id] = Self.parseISO8601Duration(iso)
            }
        }
        return result
    }

    /// Parses YouTube `PT#H#M#S` durations into seconds.
    static func parseISO8601Duration(_ iso: String) -> Double {
        // Simple PT1H2M3S parser (YouTube contentDetails.duration)
        var total = 0.0
        var number = ""
        let body = iso.uppercased().hasPrefix("PT") ? String(iso.dropFirst(2)) : iso
        for ch in body.uppercased() {
            if ch.isNumber {
                number.append(ch)
                continue
            }
            let value = Double(number) ?? 0
            number = ""
            switch ch {
            case "H": total += value * 3600
            case "M": total += value * 60
            case "S": total += value
            default: break
            }
        }
        return total
    }

    private static func getData(from url: URL?) async throws -> Data {
        guard let url else { throw YouTubeServiceError.badResponse(-1) }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw YouTubeServiceError.badResponse(-1)
        }
        // YouTube returns 200 with error payload for many key issues; still surface hard HTTP failures.
        if !(200..<300).contains(http.statusCode), http.statusCode != 400, http.statusCode != 403 {
            throw YouTubeServiceError.badResponse(http.statusCode)
        }
        return data
    }
}

// MARK: - DTOs

private struct YTSearchResponse: Decodable {
    let items: [YTSearchItem]?
    let error: YTAPIErrorBody?
}

private struct YTSearchItem: Decodable {
    let id: YTVideoID?
    let snippet: YTSnippet?
}

private struct YTVideoID: Decodable {
    let videoId: String?
}

private struct YTSnippet: Decodable {
    let title: String?
    let channelTitle: String?
    let publishedAt: Date?
    let thumbnails: YTThumbnails?
}

private struct YTThumbnails: Decodable {
    let `default`: YTThumbnail?
    let medium: YTThumbnail?
    let high: YTThumbnail?
}

private struct YTThumbnail: Decodable {
    let url: String?
}

private struct YTVideosResponse: Decodable {
    let items: [YTVideoItem]?
    let error: YTAPIErrorBody?
}

private struct YTVideoItem: Decodable {
    let id: String?
    let contentDetails: YTContentDetails?
}

private struct YTContentDetails: Decodable {
    let duration: String?
}

private struct YTAPIErrorBody: Decodable {
    let message: String?
    let code: Int?
}

private extension JSONDecoder {
    static let youtube: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var result: [[Element]] = []
        var index = 0
        while index < count {
            let end = Swift.min(index + size, count)
            result.append(Array(self[index..<end]))
            index = end
        }
        return result
    }
}
