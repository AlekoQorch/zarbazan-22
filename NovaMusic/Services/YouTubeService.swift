import Foundation

enum YouTubeServiceError: LocalizedError {
    case invalidQuery
    case badResponse(Int)
    case decoding
    case apiMessage(String)
    case noResults
    case noStream

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
        case .noStream:
            return "Couldn’t get an audio stream for this track. Try another result."
        }
    }
}

/// YouTube search + direct audio/HLS playback (background-capable via AVPlayer).
/// - Search: Data API v3 when configured, otherwise Piped.
/// - Playback: InnerTube audio/HLS first, then Piped stream URLs — never an iframe.
enum YouTubeService {
    private static let pipedBases = [
        "https://api.piped.private.coffee",
        "https://pipedapi.adminforge.de",
        "https://pipedapi.reallyaweso.me",
        "https://pipedapi.ducks.party",
        "https://pipedapi.leptons.xyz"
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

    private static let mediaSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 25
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

    // MARK: - Direct audio / HLS (lock-screen capable)

    /// Resolves a playable media URL for AVPlayer. Prefers progressive audio, then HLS, then Piped muxed/audio.
    static func resolvePlaybackURL(videoID: String) async throws -> URL {
        let id = videoID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard id.count >= 6 else { throw YouTubeServiceError.noStream }

        if let url = try? await resolveInnerTubeURL(videoID: id) {
            return url
        }
        if let url = try? await resolvePipedStreamURL(videoID: id) {
            return url
        }
        throw YouTubeServiceError.noStream
    }

    static func streamTrack(for video: YouTubeVideo, url: URL) -> StreamTrack {
        StreamTrack(
            id: "yt-\(video.id)",
            title: video.title,
            artist: video.channelTitle,
            duration: video.durationSeconds ?? 0,
            artworkURL: video.thumbnailURL,
            genre: "YouTube",
            streamURLOverride: url
        )
    }

    private static func resolveInnerTubeURL(videoID: String) async throws -> URL {
        let clients: [(name: String, key: String, ua: String, body: [String: Any])] = [
            (
                "ANDROID_VR",
                "AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w",
                "com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip",
                [
                    "context": [
                        "client": [
                            "clientName": "ANDROID_VR",
                            "clientVersion": "1.60.19",
                            "deviceMake": "Oculus",
                            "deviceModel": "Quest 3",
                            "androidSdkVersion": 32,
                            "osName": "Android",
                            "osVersion": "12L",
                            "hl": "en",
                            "gl": "US"
                        ]
                    ],
                    "videoId": videoID,
                    "contentCheckOk": true,
                    "racyCheckOk": true
                ]
            ),
            (
                "IOS",
                "AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc",
                "com.google.ios.youtube/21.26.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)",
                [
                    "context": [
                        "client": [
                            "clientName": "IOS",
                            "clientVersion": "21.26.4",
                            "deviceMake": "Apple",
                            "deviceModel": "iPhone16,2",
                            "osName": "iPhone",
                            "osVersion": "18.3.2.22D82",
                            "hl": "en",
                            "gl": "US"
                        ]
                    ],
                    "videoId": videoID,
                    "contentCheckOk": true,
                    "racyCheckOk": true
                ]
            )
        ]

        var lastError: Error = YouTubeServiceError.noStream
        for client in clients {
            do {
                guard let endpoint = URL(string: "https://www.youtube.com/youtubei/v1/player?key=\(client.key)&prettyPrint=false") else {
                    continue
                }
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(client.ua, forHTTPHeaderField: "User-Agent")
                request.httpBody = try JSONSerialization.data(withJSONObject: client.body)

                let (data, response) = try await mediaSession.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw YouTubeServiceError.badResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
                }
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw YouTubeServiceError.decoding
                }
                let status = (json["playabilityStatus"] as? [String: Any])?["status"] as? String
                guard status == "OK" || status == nil else {
                    throw YouTubeServiceError.apiMessage(status ?? "UNPLAYABLE")
                }
                if let url = pickInnerTubeAudioURL(from: json) {
                    return url
                }
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError
    }

    private static func pickInnerTubeAudioURL(from json: [String: Any]) -> URL? {
        let streaming = json["streamingData"] as? [String: Any] ?? [:]
        let adaptive = streaming["adaptiveFormats"] as? [[String: Any]] ?? []
        let progressive = streaming["formats"] as? [[String: Any]] ?? []

        let audioProgressive = adaptive.filter { format in
            let mime = (format["mimeType"] as? String ?? "").lowercased()
            return mime.contains("audio") && format["url"] is String
        }
        let ranked = audioProgressive.sorted { a, b in
            let aMp4 = ((a["mimeType"] as? String) ?? "").contains("mp4")
            let bMp4 = ((b["mimeType"] as? String) ?? "").contains("mp4")
            if aMp4 != bMp4 { return aMp4 && !bMp4 }
            let aBr = a["bitrate"] as? Int ?? 0
            let bBr = b["bitrate"] as? Int ?? 0
            return aBr > bBr
        }
        if let urlString = ranked.first?["url"] as? String, let url = URL(string: urlString) {
            return url
        }

        // Muxed progressive (itag 18 etc.) — mime is video/mp4 but includes an audio track.
        let muxed = progressive.compactMap { format -> URL? in
            guard let urlString = format["url"] as? String else { return nil }
            return URL(string: urlString)
        }
        if let first = muxed.first { return first }

        if let hls = streaming["hlsManifestUrl"] as? String, let url = URL(string: hls) {
            return url
        }
        return nil
    }

    private static func resolvePipedStreamURL(videoID: String) async throws -> URL {
        var lastError: Error = YouTubeServiceError.noStream
        for base in pipedBases {
            do {
                guard let endpoint = URL(string: "\(base)/streams/\(videoID)") else { continue }
                var request = URLRequest(url: endpoint)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("NovaMusic/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await mediaSession.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw YouTubeServiceError.badResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
                }
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw YouTubeServiceError.decoding
                }
                if let url = pickPipedAudioURL(from: json) {
                    return url
                }
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError
    }

    private static func pickPipedAudioURL(from json: [String: Any]) -> URL? {
        let audio = json["audioStreams"] as? [[String: Any]] ?? []
        let rankedAudio = audio.compactMap { item -> (Int, URL)? in
            guard let urlString = item["url"] as? String, let url = URL(string: urlString) else { return nil }
            let mime = (item["mimeType"] as? String ?? "").lowercased()
            let bitrate = item["bitrate"] as? Int ?? 0
            let score = (mime.contains("mp4") ? 1_000_000 : 0) + bitrate
            return (score, url)
        }
        .sorted { $0.0 > $1.0 }
        if let best = rankedAudio.first?.1 { return best }

        let video = json["videoStreams"] as? [[String: Any]] ?? []
        let muxed = video.compactMap { item -> URL? in
            if let only = item["videoOnly"] as? Bool, only { return nil }
            guard let urlString = item["url"] as? String else { return nil }
            // Prefer real YouTube proxies over unrelated mirrors when both exist
            return URL(string: urlString)
        }
        // Prefer piped/googlevideo proxies
        if let preferred = muxed.first(where: {
            let s = $0.absoluteString
            return s.contains("piped") || s.contains("videoplayback") || s.contains("googlevideo")
        }) {
            return preferred
        }
        if let hls = json["hls"] as? String, let url = URL(string: hls), !hls.isEmpty {
            return url
        }
        return muxed.first
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
