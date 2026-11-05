import Foundation

enum YouTubeServiceError: LocalizedError {
    case invalidQuery
    case badResponse(Int)
    case decoding
    case apiMessage(String)
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Enter at least 2 characters to search."
        case .badResponse(let code):
            return "YouTube search error (HTTP \(code))."
        case .decoding:
            return "Couldn’t read YouTube search results."
        case .apiMessage(let message):
            return message
        case .noResults:
            return "No YouTube videos found."
        }
    }
}

/// YouTube search + official embed playback.
/// - If a Data API v3 key is configured, uses Google’s official search.
/// - Otherwise uses public Piped search APIs (video id/metadata only) and plays
///   via the official YouTube IFrame / embed — no downloading.
enum YouTubeService {
    private static let pipedBases = [
        "https://api.piped.private.coffee",
        "https://pipedapi.adminforge.de",
        "https://pipedapi.reallyaweso.me"
    ]

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": "NovaMusic/1.0 (iOS; YouTubeSearch)"
        ]
        return URLSession(configuration: config)
    }()

    static func search(query: String, maxResults: Int = 25) async throws -> [YouTubeVideo] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { throw YouTubeServiceError.invalidQuery }

        if YouTubeConfig.isConfigured {
            do {
                let official = try await searchOfficial(query: trimmed, maxResults: maxResults)
                if !official.isEmpty { return official }
            } catch {
                // Fall through to Piped so search still works with a bad/missing-quota key.
            }
        }

        return try await searchPiped(query: trimmed, maxResults: maxResults)
    }

    // MARK: - Official Data API v3

    private static func searchOfficial(query: String, maxResults: Int) async throws -> [YouTubeVideo] {
        guard let apiKey = YouTubeConfig.apiKey else { throw YouTubeServiceError.apiMessage("No API key") }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "videoEmbeddable", value: "true"),
            URLQueryItem(name: "videoCategoryId", value: "10"),
            URLQueryItem(name: "maxResults", value: String(min(max(1, maxResults), 50))),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "key", value: apiKey)
        ]

        var videos = try await decodeOfficialSearch(from: components.url)
        if videos.isEmpty {
            var plain = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
            plain.queryItems = [
                URLQueryItem(name: "part", value: "snippet"),
                URLQueryItem(name: "type", value: "video"),
                URLQueryItem(name: "videoEmbeddable", value: "true"),
                URLQueryItem(name: "maxResults", value: String(min(max(1, maxResults), 50))),
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "key", value: apiKey)
            ]
            videos = try await decodeOfficialSearch(from: plain.url)
        }

        let durations = try await fetchDurations(videoIDs: videos.map(\.id), apiKey: apiKey)
        for i in videos.indices {
            videos[i].durationSeconds = durations[videos[i].id]
        }
        return videos
    }

    private static func decodeOfficialSearch(from url: URL?) async throws -> [YouTubeVideo] {
        let data = try await getData(from: url)
        let decoded: YTSearchResponse
        do {
            decoded = try JSONDecoder.youtube.decode(YTSearchResponse.self, from: data)
        } catch {
            throw YouTubeServiceError.decoding
        }
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
        guard let apiKey else { return [:] }
        let unique = Array(Set(videoIDs.filter { !$0.isEmpty }))
        guard !unique.isEmpty else { return [:] }

        var result: [String: Double] = [:]
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

    // MARK: - Piped (key-free search of YouTube catalog)

    private static func searchPiped(query: String, maxResults: Int) async throws -> [YouTubeVideo] {
        var lastError: Error = YouTubeServiceError.badResponse(-1)
        for base in pipedBases {
            do {
                var components = URLComponents(string: "\(base)/search")!
                components.queryItems = [
                    URLQueryItem(name: "q", value: query),
                    URLQueryItem(name: "filter", value: "videos")
                ]
                let data = try await getData(from: components.url, allowRedirects: true)
                let decoded = try JSONDecoder().decode(PipedSearchResponse.self, from: data)
                let videos: [YouTubeVideo] = decoded.items.compactMap { item in
                    guard item.type == nil || item.type == "stream" else { return nil }
                    guard let id = item.videoID else { return nil }
                    let thumb = URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
                    return YouTubeVideo(
                        id: id,
                        title: item.title ?? "Untitled",
                        channelTitle: item.uploaderName ?? "YouTube",
                        thumbnailURL: thumb,
                        publishedAt: nil,
                        durationSeconds: item.duration.map(Double.init)
                    )
                }
                let limited = Array(videos.prefix(maxResults))
                if !limited.isEmpty { return limited }
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError
    }

    /// Parses YouTube `PT#H#M#S` durations into seconds.
    static func parseISO8601Duration(_ iso: String) -> Double {
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

    private static func getData(from url: URL?, allowRedirects: Bool = false) async throws -> Data {
        guard let url else { throw YouTubeServiceError.badResponse(-1) }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw YouTubeServiceError.badResponse(-1)
        }
        if allowRedirects, (300..<400).contains(http.statusCode),
           let location = http.value(forHTTPHeaderField: "Location"),
           let next = URL(string: location, relativeTo: url)?.absoluteURL {
            return try await getData(from: next, allowRedirects: false)
        }
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

private struct PipedSearchResponse: Decodable {
    let items: [PipedItem]
}

private struct PipedItem: Decodable {
    let url: String?
    let type: String?
    let title: String?
    let uploaderName: String?
    let duration: Int?
    let thumbnail: String?

    var videoID: String? {
        guard let url else { return nil }
        if let range = url.range(of: "v=") {
            let id = String(url[range.upperBound...]).split(separator: "&").first.map(String.init)
            if let id, id.count >= 6 { return id }
        }
        if let range = url.range(of: "/watch?v=") {
            return String(url[range.upperBound...]).split(separator: "&").first.map(String.init)
        }
        return nil
    }
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
