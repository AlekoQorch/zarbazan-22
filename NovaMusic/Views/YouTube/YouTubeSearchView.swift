import SwiftUI

/// Real YouTube Data API v3 search + favorites / playlists / history.
struct YouTubeSearchView: View {
    @Environment(AppState.self) private var appState
    @State private var query = ""
    @State private var results: [YouTubeVideo] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedVideo: YouTubeVideo?
    @State private var playlistTarget: YouTubeVideo?
    @State private var segment: YouTubeSegment = .search
    @FocusState private var searchFocused: Bool

    enum YouTubeSegment: String, CaseIterable, Identifiable {
        case search
        case favorites
        case playlists
        var id: String { rawValue }
        var title: String {
            switch self {
            case .search: return "Search"
            case .favorites: return "Favorites"
            case .playlists: return "Playlists"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NovaTheme.Spacing.md) {
            Text("YouTube")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.novaTextPrimary)

            Picker("Section", selection: $segment) {
                ForEach(YouTubeSegment.allCases) { seg in
                    Text(seg.title).tag(seg)
                }
            }
            .pickerStyle(.segmented)

            if !YouTubeConfig.isConfigured {
                apiKeyBanner
            }

            if segment == .search {
                searchField
                searchBody
            } else if segment == .favorites {
                favoritesBody
            } else {
                playlistsBody
            }
        }
        .sheet(item: $selectedVideo) { video in
            YouTubePlayerView(video: video)
                .environment(appState)
        }
        .sheet(item: $playlistTarget) { video in
            AddToYouTubePlaylistSheet(video: video)
                .environment(appState)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: query) { _, _ in
            scheduleSearch()
        }
    }

    private var apiKeyBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YouTube API key required")
                .font(.headline)
                .foregroundStyle(Color.novaTextPrimary)
            Text("Enable YouTube Data API v3 in Google Cloud, create an API key, then paste it in Settings → YouTube. See docs/YOUTUBE_SETUP.md.")
                .font(.footnote)
                .foregroundStyle(Color.novaTextSecondary)
            Button("Open Settings") {
                appState.selectedTab = .settings
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.novaAccent)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.novaSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.novaTextSecondary)
            TextField("Song, artist, or music keyword…", text: $query)
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    appState.addSearchHistory(trimmedQuery)
                    scheduleSearch(immediate: true)
                }
            if isSearching {
                ProgressView()
                    .tint(Color.novaAccent)
            } else if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                    errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.novaAccent)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.novaSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var searchBody: some View {
        let trimmed = trimmedQuery
        if trimmed.isEmpty {
            if !appState.searchHistory.isEmpty {
                recentSearches
            } else {
                Text("Search YouTube for official music videos. Tap a result to play in the embedded player.")
                    .font(.footnote)
                    .foregroundStyle(Color.novaTextSecondary)
            }
        } else if let errorMessage {
            errorState(errorMessage)
        } else if isSearching && results.isEmpty {
            HStack(spacing: 10) {
                ProgressView()
                Text("Searching YouTube…")
                    .foregroundStyle(Color.novaTextSecondary)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        } else if !isSearching && results.isEmpty {
            emptyState
        } else {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text("Results")
                    .font(.headline)
                    .foregroundStyle(Color.novaTextPrimary)
                ForEach(results) { video in
                    YouTubeVideoRow(
                        video: video,
                        isFavorite: appState.youtube.isFavorite(video),
                        onTap: { play(video) },
                        onFavorite: { _ = appState.youtube.toggleFavorite(video) },
                        onAddToPlaylist: { playlistTarget = video }
                    )
                }
            }
        }
    }

    private var recentSearches: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent searches")
                    .font(.headline)
                Spacer()
                Button("Clear") { appState.clearSearchHistory() }
                    .font(.subheadline)
                    .foregroundStyle(Color.novaAccent)
            }
            ForEach(appState.searchHistory.prefix(10), id: \.self) { term in
                Button {
                    query = term
                    searchFocused = true
                    scheduleSearch(immediate: true)
                } label: {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(Color.novaTextSecondary)
                        Text(term)
                            .foregroundStyle(Color.novaTextPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var favoritesBody: some View {
        Group {
            if appState.youtube.favorites.isEmpty {
                ContentUnavailableView(
                    "No favorites yet",
                    systemImage: "heart",
                    description: Text("Favorite videos from search or while watching.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(appState.youtube.favorites) { video in
                        YouTubeVideoRow(
                            video: video,
                            isFavorite: true,
                            onTap: { play(video) },
                            onFavorite: { _ = appState.youtube.toggleFavorite(video) },
                            onAddToPlaylist: { playlistTarget = video }
                        )
                    }
                }
            }
        }
    }

    private var playlistsBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            if appState.youtube.playlists.isEmpty {
                ContentUnavailableView(
                    "No playlists yet",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Create a playlist when adding a video, or from the player.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(appState.youtube.playlists) { playlist in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(playlist.name)
                                .font(.headline)
                            Spacer()
                            Text("\(playlist.videos.count)")
                                .font(.caption)
                                .foregroundStyle(Color.novaTextSecondary)
                            Button(role: .destructive) {
                                appState.youtube.deletePlaylist(playlist.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                        }
                        if playlist.videos.isEmpty {
                            Text("Empty playlist")
                                .font(.caption)
                                .foregroundStyle(Color.novaTextSecondary)
                        } else {
                            ForEach(playlist.videos) { video in
                                YouTubeVideoRow(
                                    video: video,
                                    isFavorite: appState.youtube.isFavorite(video),
                                    onTap: { play(video) },
                                    onFavorite: { _ = appState.youtube.toggleFavorite(video) }
                                )
                                .contextMenu {
                                    Button(role: .destructive) {
                                        appState.youtube.removeVideo(id: video.id, fromPlaylist: playlist.id)
                                    } label: {
                                        Label("Remove from Playlist", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(Color.novaTextSecondary)
            Text("No videos for “\(trimmedQuery)”")
                .foregroundStyle(Color.novaTextPrimary)
            Text("Try another song, artist, or keyword.")
                .font(.footnote)
                .foregroundStyle(Color.novaTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Couldn’t search")
                .font(.headline)
                .foregroundStyle(Color.novaTextPrimary)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color.novaTextSecondary)
            Button("Retry") { scheduleSearch(immediate: true) }
                .foregroundStyle(Color.novaAccent)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.novaSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func play(_ video: YouTubeVideo) {
        appState.addSearchHistory(trimmedQuery.isEmpty ? video.title : trimmedQuery)
        selectedVideo = video
    }

    private func scheduleSearch(immediate: Bool = false) {
        searchTask?.cancel()
        let q = trimmedQuery
        guard q.count >= 2 else {
            results = []
            errorMessage = nil
            isSearching = false
            return
        }
        guard YouTubeConfig.isConfigured else {
            errorMessage = YouTubeServiceError.missingAPIKey.localizedDescription
            results = []
            isSearching = false
            return
        }
        isSearching = true
        errorMessage = nil
        searchTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 320_000_000)
            }
            guard !Task.isCancelled else { return }
            do {
                let videos = try await YouTubeService.search(query: q)
                guard !Task.isCancelled else { return }
                results = videos
                isSearching = false
                if !videos.isEmpty {
                    appState.addSearchHistory(q)
                }
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                isSearching = false
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
