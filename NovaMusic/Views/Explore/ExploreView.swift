import SwiftUI

/// Explore — YouTube (Data API v3), free Audius streams, and local library discovery.
struct ExploreView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NovaTheme.Spacing.lg) {
                    Picker("Explore", selection: $state.exploreSegment) {
                        ForEach(ExploreSegment.allCases) { segment in
                            Text(segment.title).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, NovaTheme.Spacing.sm)

                    switch state.exploreSegment {
                    case .youtube:
                        YouTubeSearchView()
                    case .streaming:
                        AudiusExploreContent()
                    case .library:
                        LibraryExploreContent()
                    }
                }
                .padding(.horizontal, NovaTheme.Spacing.md)
                .padding(.bottom, 120)
            }
            .novaScreen()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Audius (free stream) content

private struct AudiusExploreContent: View {
    @Environment(AppState.self) private var appState
    @State private var query = ""
    @State private var onlineResults: [StreamTrack] = []
    @State private var trending: [StreamTrack] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: NovaTheme.Spacing.lg) {
            Text(trimmedQuery.isEmpty ? "Free music" : "Results")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.novaTextPrimary)
            Text("No Google key needed — search and play instantly.")
                .font(.footnote)
                .foregroundStyle(Color.novaTextSecondary)

            searchField

            if trimmedQuery.isEmpty {
                if !trending.isEmpty {
                    VStack(alignment: .leading, spacing: NovaTheme.Spacing.sm) {
                        Text("Listen now")
                            .font(.title3.weight(.bold))
                        Text("Artist-uploaded streams (Audius)")
                            .font(.footnote)
                            .foregroundStyle(Color.novaTextSecondary)
                        ForEach(trending.prefix(12)) { track in
                            StreamRowView(
                                track: track,
                                isPlaying: appState.player.currentStream?.id == track.id && appState.player.isPlaying
                            ) {
                                appState.player.playStream(track, in: trending)
                                appState.player.showsNowPlaying = true
                            }
                        }
                    }
                }
            } else {
                if let searchError {
                    Text(searchError)
                        .font(.footnote)
                        .foregroundStyle(Color.novaTextSecondary)
                }
                if isSearching && onlineResults.isEmpty {
                    ProgressView()
                        .tint(Color.novaAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
                ForEach(onlineResults) { track in
                    StreamRowView(
                        track: track,
                        isPlaying: appState.player.currentStream?.id == track.id && appState.player.isPlaying
                    ) {
                        appState.addSearchHistory(trimmedQuery)
                        appState.player.playStream(track, in: onlineResults)
                        appState.player.showsNowPlaying = true
                    }
                }
                if !isSearching && onlineResults.isEmpty && searchError == nil {
                    Text("No free streams for “\(trimmedQuery)”")
                        .foregroundStyle(Color.novaTextSecondary)
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .task { await loadTrending() }
        .onChange(of: query) { _, _ in scheduleOnlineSearch() }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.novaTextSecondary)
            TextField("Search free catalog…", text: $query)
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if isSearching {
                ProgressView().tint(Color.novaAccent)
            } else if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.novaAccent)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.novaSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func scheduleOnlineSearch() {
        searchTask?.cancel()
        let q = trimmedQuery
        guard q.count >= 2 else {
            onlineResults = []
            searchError = nil
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            do {
                let results = try await AudiusService.search(query: q)
                guard !Task.isCancelled else { return }
                onlineResults = results
                searchError = nil
                isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                onlineResults = []
                searchError = "Couldn’t reach free catalog."
                isSearching = false
            }
        }
    }

    private func loadTrending() async {
        trending = (try? await AudiusService.trending(limit: 16)) ?? []
    }
}

// MARK: - Local library discovery

private struct LibraryExploreContent: View {
    @Environment(AppState.self) private var appState
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: NovaTheme.Spacing.lg) {
            Text("Your library")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.novaTextPrimary)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.novaTextSecondary)
                TextField("Search imported music…", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.novaSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if trimmed.isEmpty {
                Text("Import tracks from Files to search them here. YouTube and Free tabs play online.")
                    .font(.footnote)
                    .foregroundStyle(Color.novaTextSecondary)
            } else if filtered.isEmpty {
                Text("No local matches")
                    .foregroundStyle(Color.novaTextSecondary)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(filtered, id: \.id) { song in
                    SongRowView(song: song, isPlaying: appState.player.currentSong?.id == song.id) {
                        appState.addSearchHistory(trimmed)
                        appState.player.play(song: song, in: filtered)
                    }
                }
            }
        }
    }

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filtered: [Song] {
        guard !trimmed.isEmpty else { return [] }
        return appState.library.songs.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
            || $0.artist.localizedCaseInsensitiveContains(trimmed)
            || $0.album.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
