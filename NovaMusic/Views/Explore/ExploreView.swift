import SwiftUI

/// Library discovery — Music X–style Explore, for *your* imported music only.
/// No YouTube / remote download.
struct ExploreView: View {
    @Environment(AppState.self) private var appState
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NovaTheme.Spacing.lg) {
                    header
                    searchField

                    if trimmedQuery.isEmpty {
                        discoverGrid
                        if !appState.searchHistory.isEmpty {
                            recentSearches
                        }
                    } else if filteredSongs.isEmpty && filteredArtists.isEmpty && filteredAlbums.isEmpty {
                        emptyResults
                    } else {
                        searchResults
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
            TextField("Music, Artist, Playlist...", text: $query)
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    appState.addSearchHistory(trimmedQuery)
                }
            if !query.isEmpty {
                Button {
                    query = ""
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

    private var discoverGrid: some View {
        VStack(alignment: .leading, spacing: NovaTheme.Spacing.sm) {
            Text("Explore your library")
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

                ExploreCard(
                    title: "Most played",
                    subtitle: appState.library.mostPlayed.isEmpty ? "Play something" : "Your hits",
                    systemImage: "chart.bar.fill",
                    colors: [Color(red: 0.2, green: 0.7, blue: 0.55), Color(red: 0.1, green: 0.3, blue: 0.28)]
                ) {
                    playList(appState.library.mostPlayed)
                }

                ExploreCard(
                    title: "Playlists",
                    subtitle: "\(appState.playlists.playlists.count) playlists",
                    systemImage: "music.note.list",
                    colors: [Color(red: 0.55, green: 0.35, blue: 0.9), Color(red: 0.25, green: 0.15, blue: 0.4)]
                ) {
                    appState.selectedTab = .playlists
                }
            }

            if appState.library.songs.isEmpty {
                Text("Import music first — Explore searches your offline library, not the internet.")
                    .font(.footnote)
                    .foregroundStyle(Color.novaTextSecondary)
                    .padding(.top, 8)
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

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: NovaTheme.Spacing.md) {
            if !filteredSongs.isEmpty {
                Text("Songs")
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
            Text("Try another spelling, or import more music.")
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
