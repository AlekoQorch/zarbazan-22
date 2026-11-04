import Foundation
import SwiftData
import SwiftUI

@MainActor
final class PersistenceManager {
    static let shared = PersistenceManager()

    let container: ModelContainer
    let context: ModelContext

    private let snapshotURL: URL
    private let searchHistoryKey = "nova.searchHistory"
    private let settingsKey = "nova.appSettings"

    private init() {
        let schema = Schema([
            Song.self,
            Playlist.self,
            PlaylistItem.self
        ])
        let configuration = ModelConfiguration(
            "NovaMusic",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            container = try! ModelContainer(for: schema, configurations: [fallback])
        }
        context = container.mainContext
        context.autosaveEnabled = true
        snapshotURL = FileStorage.snapshotsDirectory.appendingPathComponent("playback.json")
        FileStorage.ensureDirectory(FileStorage.musicDirectory)
        FileStorage.ensureDirectory(FileStorage.artworkDirectory)
    }

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("NovaMusic: failed to save context — \(error)")
        }
    }

    func loadPlaybackSnapshot() -> PlaybackSnapshot {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder().decode(PlaybackSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    func savePlaybackSnapshot(_ snapshot: PlaybackSnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: snapshotURL, options: [.atomic])
        } catch {
            print("NovaMusic: failed to save playback snapshot — \(error)")
        }
    }

    func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func saveSettings(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    func loadSearchHistory() -> [String] {
        UserDefaults.standard.stringArray(forKey: searchHistoryKey) ?? []
    }

    func saveSearchHistory(_ history: [String]) {
        UserDefaults.standard.set(history, forKey: searchHistoryKey)
    }
}

struct AppSettings: Codable, Equatable {
    var appearance: AppearanceMode
    var resumePlaybackOnLaunch: Bool
    var rememberPosition: Bool
    var equalizerPreset: EqualizerPreset
    var crossfadeEnabled: Bool
    var hapticFeedback: Bool

    static let `default` = AppSettings(
        appearance: .system,
        resumePlaybackOnLaunch: true,
        rememberPosition: true,
        equalizerPreset: .off,
        crossfadeEnabled: false,
        hapticFeedback: true
    )
}

enum AppearanceMode: String, CaseIterable, Codable, Identifiable {
    case system
    case dark
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}
