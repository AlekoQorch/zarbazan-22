import Foundation
import SwiftData
import UniformTypeIdentifiers

@MainActor
@Observable
final class ImportManager {
    private(set) var isImporting = false
    private(set) var progress: ImportProgress = .idle
    private(set) var lastSummary: ImportProgress?

    var showsProgressSheet = false

    private let persistence: PersistenceManager

    init(persistence: PersistenceManager = .shared) {
        self.persistence = persistence
    }

    func importFiles(from urls: [URL]) async {
        guard !urls.isEmpty else { return }
        isImporting = true
        showsProgressSheet = true
        progress = ImportProgress(
            total: urls.count,
            completed: 0,
            currentFileName: "",
            succeeded: 0,
            failed: 0,
            skippedDuplicates: 0,
            errors: []
        )

        let context = persistence.context
        var existingHashes = Set(fetchAllHashes(context: context))

        for url in urls {
            progress.currentFileName = url.lastPathComponent

            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
                // Clean staged import copies under TemporaryDirectory/nova-import-*
                cleanupStagedIfNeeded(url)
            }

            do {
                let result = try await importSingleFile(url: url, existingHashes: &existingHashes, context: context)
                switch result {
                case .imported:
                    progress.succeeded += 1
                case .duplicate:
                    progress.skippedDuplicates += 1
                }
            } catch {
                progress.failed += 1
                progress.errors.append(
                    ImportFileError(fileName: url.lastPathComponent, message: error.localizedDescription)
                )
            }

            progress.completed += 1
            // Yield so the progress UI can refresh.
            await Task.yield()
        }

        persistence.save()
        lastSummary = progress
        isImporting = false
    }

    private enum ImportResult {
        case imported
        case duplicate
    }

    private enum ImportError: LocalizedError {
        case unsupported
        case copyFailed
        case unreadable

        var errorDescription: String? {
            switch self {
            case .unsupported: return "Unsupported or unreadable audio format."
            case .copyFailed: return "Could not copy the file into Nova Music storage."
            case .unreadable: return "The file could not be read."
            }
        }
    }

    private func importSingleFile(
        url: URL,
        existingHashes: inout Set<String>,
        context: ModelContext
    ) async throws -> ImportResult {
        guard MetadataExtractor.isSupported(url: url) else {
            throw ImportError.unsupported
        }

        let workingURL: URL
        let shouldDeleteWorking: Bool

        // If already in tmp (staged by picker), use directly; otherwise copy first.
        if url.path.contains("/tmp/") || url.path.contains("nova-import-") {
            workingURL = url
            shouldDeleteWorking = false
        } else {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "." + url.pathExtension)
            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: url, to: tempURL)
            } catch {
                throw ImportError.copyFailed
            }
            workingURL = tempURL
            shouldDeleteWorking = true
        }

        defer {
            if shouldDeleteWorking {
                FileStorage.deleteIfExists(workingURL)
            }
        }

        let hash: String
        do {
            hash = try FileStorage.sha256(ofFileAt: workingURL)
        } catch {
            throw ImportError.unreadable
        }

        if existingHashes.contains(hash) {
            return .duplicate
        }

        let metadata = await MetadataExtractor.extract(from: workingURL)
        let attrs = try? FileManager.default.attributesOfItem(atPath: workingURL.path)
        let size = attrs?[.size] as? Int64 ?? 0
        if size == 0 {
            throw ImportError.unreadable
        }

        let fileName = FileStorage.uniqueFileName(originalName: url.lastPathComponent, hashPrefix: hash)
        let destination = FileStorage.musicFileURL(fileName: fileName)

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: workingURL, to: destination)
        } catch {
            throw ImportError.copyFailed
        }

        var artworkRelative: String?
        if let artData = metadata.artworkData,
           let jpeg = MetadataExtractor.downsampleArtwork(artData) {
            let artName = "\(hash.prefix(16)).jpg"
            let artURL = FileStorage.artworkFileURL(fileName: artName)
            try? jpeg.write(to: artURL, options: [.atomic])
            artworkRelative = FileStorage.relativePath(from: artURL)
        }

        let song = Song(
            title: metadata.title,
            artist: metadata.artist,
            album: metadata.album,
            genre: metadata.genre,
            trackNumber: metadata.trackNumber,
            duration: metadata.duration,
            relativeFilePath: FileStorage.relativePath(from: destination),
            artworkRelativePath: artworkRelative,
            fileHash: hash,
            fileSize: size,
            fileExtension: destination.pathExtension.lowercased()
        )

        context.insert(song)
        existingHashes.insert(hash)
        return .imported
    }

    private func cleanupStagedIfNeeded(_ url: URL) {
        // Remove the nova-import-* parent folder if present.
        let parent = url.deletingLastPathComponent()
        if parent.lastPathComponent.hasPrefix("nova-import-") {
            FileStorage.deleteIfExists(parent)
        }
    }

    private func fetchAllHashes(context: ModelContext) -> [String] {
        let descriptor = FetchDescriptor<Song>()
        let songs = (try? context.fetch(descriptor)) ?? []
        return songs.map(\.fileHash)
    }

    func dismissProgress() {
        showsProgressSheet = false
    }
}
