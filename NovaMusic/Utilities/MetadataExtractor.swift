import Foundation
import AVFoundation
import UIKit
import UniformTypeIdentifiers

struct ExtractedMetadata: Sendable {
    var title: String
    var artist: String
    var album: String
    var genre: String
    var trackNumber: Int
    var duration: Double
    var artworkData: Data?
}

enum MetadataExtractor {
    static let supportedTypes: [UTType] = {
        var types: [UTType] = [
            .mp3, .mpeg4Audio, .wav, .aiff, .audio
        ]
        if let aac = UTType(filenameExtension: "aac") { types.append(aac) }
        if let m4a = UTType(filenameExtension: "m4a") { types.append(m4a) }
        if let caf = UTType(filenameExtension: "caf") { types.append(caf) }
        if let flac = UTType(filenameExtension: "flac") { types.append(flac) }
        return types
    }()

    static let supportedExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "aiff", "aif", "caf", "flac", "mp4", "m4b"
    ]

    static func isSupported(url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func extract(from url: URL) async -> ExtractedMetadata {
        let asset = AVURLAsset(url: url)
        let fallbackTitle = url.deletingPathExtension().lastPathComponent

        var title = fallbackTitle
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var genre = ""
        var trackNumber = 0
        var duration: Double = 0
        var artworkData: Data?

        do {
            let durationTime = try await asset.load(.duration)
            duration = durationTime.seconds.isFinite ? durationTime.seconds : 0
        } catch {
            duration = 0
        }

        do {
            let metadata = try await asset.load(.commonMetadata)
            for item in metadata {
                guard let key = item.commonKey else { continue }
                switch key {
                case .commonKeyTitle:
                    if let value = try? await item.load(.stringValue), !value.isEmpty {
                        title = value
                    }
                case .commonKeyArtist:
                    if let value = try? await item.load(.stringValue), !value.isEmpty {
                        artist = value
                    }
                case .commonKeyAlbumName:
                    if let value = try? await item.load(.stringValue), !value.isEmpty {
                        album = value
                    }
                case .commonKeyType:
                    if let value = try? await item.load(.stringValue), !value.isEmpty {
                        genre = value
                    }
                case .commonKeyArtwork:
                    if let data = try? await item.load(.dataValue) {
                        artworkData = data
                    }
                default:
                    break
                }
            }
        } catch {
            // Keep fallbacks.
        }

        // iTunes / ID3 extras
        do {
            let all = try await asset.load(.metadata)
            for item in all {
                let identifier = item.identifier?.rawValue ?? ""
                if trackNumber == 0,
                   identifier.contains("trackNumber") || identifier.contains("TRCK"),
                   let value = try? await item.load(.stringValue),
                   let number = Int(value.split(separator: "/").first ?? Substring(value)) {
                    trackNumber = number
                }
                if genre.isEmpty,
                   identifier.contains("genre") || identifier.contains("TCON"),
                   let value = try? await item.load(.stringValue), !value.isEmpty {
                    genre = value
                }
            }
        } catch {
            // Ignore.
        }

        return ExtractedMetadata(
            title: title,
            artist: artist,
            album: album,
            genre: genre,
            trackNumber: trackNumber,
            duration: duration,
            artworkData: artworkData
        )
    }

    static func downsampleArtwork(_ data: Data, maxDimension: CGFloat = 1024) -> Data? {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else {
            return image.jpegData(compressionQuality: 0.88) ?? data
        }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.88)
    }
}
