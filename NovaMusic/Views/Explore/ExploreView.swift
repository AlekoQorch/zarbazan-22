import SwiftUI

/// Explore — search online catalog (Audius) and play streams, plus local library matches.
struct ExploreView: View {
    @Environment(AppState.self) private var appState
    @State private var query = ""
    @State private var onlineResults: [StreamTrack] = []
    @State private var trending: [StreamTrack] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NovaTheme.Spacing.lg) {
                    header
                    searchField

                    if trimmedQuery.isEmpty {
                        trendingSection
                        discoverGrid
                        if !appState.searchHistory.isEmpty {
                            recentSearches
                        }
                    } else {
                        onlineSection
                        if !filteredSongs.isEmpty || !filteredArtists.isEmpty || !filteredAlbums.isEmpty {
                            localResults
                        }
                        if !isSearching && onlineResults.isEmpty && filteredSongs.isEmpty
                            && filteredArtists.isEmpty && filteredAlbums.isEmpty {
                            emptyResults
                        }
                    }
                }
                .padding(.horizontal, NovaTheme.Spacing.md)
                .padding(.bottom, 120)
            }
            .novaScreen()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task { await loadTrending() }
            .onChange(of: query) { _, _ in
                scheduleOnlineSearch()
            }
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var header: some View {
        Text(trimmedQuery.isEmpty ? "Search for everything" : "Results")
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(Color.novaTextPrimary)
            .padding(.top, NovaTheme.Spacing.md)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.novaTextSecondary)
            TextField("Song, artist, mood…", text: $query)
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    appState.addSearchHistory(trimmedQuery)
                    scheduleOnlineSearch(immediate: true)
                }
            if isSearching {
                ProgressView()
                    .tint(Color.novaAccent)
            } else if !query.isEmpty {
                Button {
                    query = ""
                    onlineResults = []
                    searchError = nil
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
    private var trendingSection: some View {
        if !trending.isEmpty {
            VStack(alignment: .leading, spacing: NovaTheme.Spacing.sm) {
                Text("Listen now")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.novaTextPrimary)
                Text("Free music from Audius — tap to play")
                    .font(.footnote)
                    .foregroundStyle(Color.novaTextSecondary)

                ForEach(trending.prefix(12)) { track in
                    StreamRowView(
                        track: track,
                        isPlaying: appState.player.currentStream?.id == track.id && appState.player.isPlaying
                    ) {
                        playOnline(track, in: trending)
                    }
                }
            }
        }
    }

    private var discoverGrid: some View {
        VStack(alignment: .leading, spacing: NovaTheme.Spacing.sm) {
            Text("Your library")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.novaTextPrimary)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ExploreCard(
                    title: "Top artists",
                    subtitle: "\(appState.library.artists.count) in library",
                    systemImage: "person.2.fill",
                    colors: [Color.novaAccent.opacity(0.85), Color.novaAccent.opacity(0.35)]
                ) {
                    appState.selectedTab = .library
                    appState.librarySegment = .artists
                }

                ExploreCard(
                    title: "Recently added",
                    subtitle: "\(min(appState.library.recentlyAdded.count, 20)) tracks",
                    systemImage: "clock.fill",
                    colors: [Color(red: 0.35, green: 0.45, blue: 0.95), Color(red: 0.15, green: 0.2, blue: 0.45)]
                ) {
                    playList(appState.library.recentlyAdded)
                }

                ExploreCard(
                    title: "Liked songs",
                    subtitle: "\(appState.library.favorites.count) favorites",
                    systemImage: "heart.fill",
                    colors: [Color(red: 0.85, green: 0.25, blue: 0.45), Color(red: 0.4, green: 0.1, blue: 0.25)]
                ) {
                    playList(appState.library.favorites)
                }

                ExploreCard(
                    title: "Albums",
                    subtitle: "\(appState.library.albums.count) albums",
                    systemImage: "square.stack.fill",
                    colors: [Color(red: 0.95, green: 0.55, blue: 0.2), Color(red: 0.45, green: 0.2, blue: 0.1)]
                ) {
                    appState.selectedTab = .library
                    appState.librarySegment = .albums
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
            ForEach(appState.searchHistory.prefix(8), id: \.self) { term in
                Button {
                    query = term
                    searchFocused = true
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

    @ViewBuilder
    private var onlineSection: some View {
        VStack(alignment: .leading, spacing: NovaTheme.Spacing.sm) {
            HStack {
                Text("Online")
                    .font(.headline)
                    .foregroundStyle(Color.novaTextPrimary)
                Spacer()
                if !onlineResults.isEmpty {
                    Text("\(onlineResults.count)")
                        .font(.caption)
                        .foregroundStyle(Color.novaTextSecondary)
                }
            }

            if let searchError {
                Text(searchError)
                    .font(.footnote)
                    .foregroundStyle(Color.novaTextSecondary)
            }

            ForEach(onlineResults) { track in
                StreamRowView(
                    track: track,
                    isPlaying: appState.player.currentStream?.id == track.id && appState.player.isPlaying
                ) {
                    appState.addSearchHistory(trimmedQuery)
                    playOnline(track, in: onlineResults)
                }
            }
        }
    }

    private var localResults: some View {
        VStack(alignment: .leading, spacing: NovaTheme.Spacing.md) {
            if !filteredSongs.isEmpty {
                Text("On this iPhone")
                    .font(.headline)
                ForEach(filteredSongs, id: \.id) { song in
                    SongRowView(song: song, isPlaying: appState.player.currentSong?.id == song.id) {
                        appState.addSearchHistory(trimmedQuery)
                        appState.player.play(song: song, in: filteredSongs)
                    }
                }
            }
            if !filteredArtists.isEmpty {
                Text("Artists")
                    .font(.headline)
                    .padding(.top, 8)
                ForEach(filteredArtists) { artist in
                    Button {
                        playList(artist.songs)
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title)
                                .foregroundStyle(Color.novaTextSecondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(artist.name)
                                    .foregroundStyle(Color.novaTextPrimary)
                                Text("\(artist.songs.count) songs")
                                    .font(.caption)
                                    .foregroundStyle(Color.novaTextSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            if !filteredAlbums.isEmpty {
                Text("Albums")
                    .font(.headline)
                    .padding(.top, 8)
                ForEach(filteredAlbums) { album in
                    Button {
                        playList(album.songs)
                    } label: {
                        HStack(spacing: 12) {
                            ArtworkView(song: album.artworkSong)
                                .frame(width: 52, height: 52)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(album.name)
                                    .foregroundStyle(Color.novaTextPrimary)
                                Text(album.artist)
                                    .font(.caption)
                                    .foregroundStyle(Color.novaTextSecondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var emptyResults: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(Color.novaTextSecondary)
            Text("No results for “\(trimmedQuery)”")
                .foregroundStyle(Color.novaTextPrimary)
            Text("Try another spelling or mood.")
                .font(.footnote)
                .foregroundStyle(Color.novaTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var filteredSongs: [Song] {
        let q = trimmedQuery
        guard !q.isEmpty else { return [] }
        return appState.library.songs.filter {
            $0.title.localizedCaseInsensitiveContains(q)
            || $0.artist.localizedCaseInsensitiveContains(q)
            || $0.album.localizedCaseInsensitiveContains(q)
            || $0.genre.localizedCaseInsensitiveContains(q)
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private var filteredArtists: [ArtistGroup] {
        let q = trimmedQuery
        guard !q.isEmpty else { return [] }
        return appState.library.artists.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private var filteredAlbums: [AlbumGroup] {
        let q = trimmedQuery
        guard !q.isEmpty else { return [] }
        return appState.library.albums.filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.artist.localizedCaseInsensitiveContains(q)
        }
    }

    private func playList(_ songs: [Song]) {
        guard !songs.isEmpty else { return }
        appState.player.play(songs: songs, startAt: 0)
        appState.player.showsNowPlaying = true
    }

    private func playOnline(_ track: StreamTrack, in context: [StreamTrack]) {
        appState.player.playStream(track, in: context)
        appState.player.showsNowPlaying = true
    }

    private func scheduleOnlineSearch(immediate: Bool = false) {
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
            if !immediate {
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
            guard !Task.isCancelled else { return }
            do {
                let results = try await AudiusService.search(query: q)
                guard !Task.isCancelled else { return }
                onlineResults = results
                searchError = results.isEmpty ? nil : nil
                isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                onlineResults = []
                searchError = "Couldn’t reach online catalog. Check connection."
                isSearching = false
            }
        }
    }

    private func loadTrending() async {
        do {
            trending = try await AudiusService.trending(limit: 16)
        } catch {
            trending = []
        }
    }
}

struct StreamRowView: View {
    let track: StreamTrack
    var isPlaying: Bool = false
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                RemoteArtworkView(url: track.artworkURL, title: track.title, artist: track.artist, cornerRadius: 8)
                    .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.body.weight(isPlaying ? .semibold : .regular))
                        .foregroundStyle(isPlaying ? Color.novaAccent : Color.novaTextPrimary)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(Color.novaTextSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(DurationFormatter.string(from: track.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.novaTextSecondary)
                Image(systemName: isPlaying ? "speaker.wave.2.fill" : "play.fill")
                    .font(.caption)
                    .foregroundStyle(Color.novaAccent)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

private struct ExploreCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let colors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(height: 110)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: systemImage)
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(12)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(12)
            }
        }
        .buttonStyle(.plain)
    }
}
