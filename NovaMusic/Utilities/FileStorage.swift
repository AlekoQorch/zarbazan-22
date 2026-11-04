import Foundation
import CryptoKit

enum FileStorage {
    static var applicationSupportURL: URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let base = urls[0].appendingPathComponent("NovaMusic", isDirectory: true)
        ensureDirectory(base)
        return base
    }

    static var musicDirectory: URL {
        let url = applicationSupportURL.appendingPathComponent("Music", isDirectory: true)
        ensureDirectory(url)
        return url
    }

    static var artworkDirectory: URL {
        let url = applicationSupportURL.appendingPathComponent("Artwork", isDirectory: true)
        ensureDirectory(url)
        return url
    }

    static var snapshotsDirectory: URL {
        let url = applicationSupportURL.appendingPathComponent("Snapshots", isDirectory: true)
        ensureDirectory(url)
        return url
    }

    static func ensureDirectory(_ url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    static func absoluteURL(forRelativePath relative: String) -> URL {
        applicationSupportURL.appendingPathComponent(relative)
    }

    static func musicFileURL(fileName: String) -> URL {
        musicDirectory.appendingPathComponent(fileName)
    }

    static func artworkFileURL(fileName: String) -> URL {
        artworkDirectory.appendingPathComponent(fileName)
    }

    static func relativePath(from absolute: URL) -> String {
        let base = applicationSupportURL.path
        let path = absolute.path
        if path.hasPrefix(base) {
            let trimmed = String(path.dropFirst(base.count))
            return trimmed.hasPrefix("/") ? String(trimmed.dropFirst()) : trimmed
        }
        return absolute.lastPathComponent
    }

    static func sha256(ofFileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 1024 * 1024)
            if chunk.isEmpty { return false }
            hasher.update(data: chunk)
            return true
        }) {}

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func uniqueFileName(originalName: String, hashPrefix: String) -> String {
        let ext = (originalName as NSString).pathExtension
        let base = (originalName as NSString).deletingPathExtension
        let sanitized = base
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let shortHash = String(hashPrefix.prefix(12))
        if ext.isEmpty {
            return "\(sanitized)-\(shortHash)"
        }
        return "\(sanitized)-\(shortHash).\(ext)"
    }

    static func deleteIfExists(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
