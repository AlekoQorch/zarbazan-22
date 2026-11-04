import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NovaTheme.Spacing.xl) {
                    header

                    if appState.library.songs.isEmpty {
                        EmptyLibraryOnboarding(showImporter: $showImporter)
                            .padding(.top, NovaTheme.Spacing.lg)
                    } else {
                        importCTA

                        if !appState.library.recentlyPlayed.isEmpty {
                            shelf(title: "Recently Played", songs: appState.library.recentlyPlayed)
                        }

                        if !appState.library.recentlyAdded.isEmpty {
                            shelf(title: "Recently Added", songs: appState.library.recentlyAdded)
                        }

                        if !appState.library.favorites.isEmpty {
                            shelf(title: "Favorites", songs: appState.library.favorites)
                        }

                        if !appState.playlists.recentlyPlayedPlaylists.isEmpty {
                            playlistShelf
                        }

                        libraryShortcut
                    }
                }
                .padding(.horizontal, NovaTheme.Spacing.md)
                .padding(.bottom, 100)
            }
            .novaScreen()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Import Music")
                }
            }
            .sheet(isPresented: $showImporter) {
                MusicDocumentPicker { urls in
                    showImporter = false
                    Task { await appState.importer.importFiles(from: urls) }
                }
                .ignoresSafeArea()
            }
            .onAppear { appState.refreshAll() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NOVA")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Color.novaTextPrimary)
                .tracking(4)
            Text(appState.library.songs.isEmpty ? "Your offline music, beautifully simple." : "Listen offline.")
                .font(.subheadline)
                .foregroundStyle(Color.novaTextSecondary)
        }
        .padding(.top, NovaTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var importCTA: some View {
        Button {
            showImporter = true
        } label: {
            Label("Import Music", systemImage: "square.and.arrow.down")
        }
        .buttonStyle(NovaPrimaryButtonStyle())
    }

    private func shelf(title: String, songs: [Song]) -> some View {
        VStack(alignment: .leading, spacing: NovaTheme.Spacing.sm) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.novaTextPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NovaTheme.Spacing.sm) {
                    ForEach(songs) { song in
                        Button {
                            appState.player.play(song: song, in: songs)
                            appState.player.showsNowPlaying = true
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ArtworkView(song: song)
                                    .frame(width: 140, height: 140)
                                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                                Text(song.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.novaTextPrimary)
                                    .lineLimit(1)
                                Text(song.artist)
                                    .font(.caption)
                                    .foregroundStyle(Color.novaTextSecondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 140, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var playlistShelf: some View {
        VStack(alignment: .leading, spacing: NovaTheme.Spacing.sm) {
            Text("Recent Playlists")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.novaTextPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NovaTheme.Spacing.sm) {
                    ForEach(appState.playlists.recentlyPlayedPlaylists) { playlist in
                        Button {
                            let songs = playlist.songs
                            guard !songs.isEmpty else { return }
                            appState.playlists.markPlayed(playlist)
                            appState.player.play(songs: songs, startAt: 0)
                            appState.player.showsNowPlaying = true
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                playlistArt(playlist)
                                    .frame(width: 140, height: 140)
                                Text(playlist.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.novaTextPrimary)
                                    .lineLimit(1)
                                Text("\(playlist.songCount) songs")
                                    .font(.caption)
                                    .foregroundStyle(Color.novaTextSecondary)
                            }
                            .frame(width: 140, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func playlistArt(_ playlist: Playlist) -> some View {
        if let id = playlist.artworkSongID,
           let song = appState.library.song(id: id) {
            ArtworkView(song: song)
        } else if let song = playlist.songs.first {
            ArtworkView(song: song)
        } else {
            PlaceholderArtwork(title: playlist.name, artist: "")
                .clipShape(RoundedRectangle(cornerRadius: NovaTheme.Radius.artwork, style: .continuous))
        }
    }

    private var libraryShortcut: some View {
        Button {
            appState.selectedTab = .library
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Full Library")
                        .font(.headline)
                        .foregroundStyle(Color.novaTextPrimary)
                    Text("\(appState.library.songs.count) songs")
                        .font(.caption)
                        .foregroundStyle(Color.novaTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.novaTextSecondary)
            }
            .padding(NovaTheme.Spacing.md)
            .background(Color.novaSurface)
            .clipShape(RoundedRectangle(cornerRadius: NovaTheme.Radius.large, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct EmptyLibraryOnboarding: View {
    @Binding var showImporter: Bool

    var body: some View {
        VStack(spacing: NovaTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.novaAccent.opacity(0.28), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 140
                        )
                    )
                    .frame(width: 260, height: 260)
                Image(systemName: "waveform")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(Color.novaAccent)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            }

            VStack(spacing: NovaTheme.Spacing.sm) {
                Text("Import your music")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.novaTextPrimary)
                Text("Add MP3, M4A, AAC, WAV and other audio files from the Files app. Everything stays on your iPhone — offline, forever yours.")
                    .font(.body)
                    .foregroundStyle(Color.novaTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showImporter = true
            } label: {
                Label("Import Music", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(NovaPrimaryButtonStyle())
            .padding(.horizontal, NovaTheme.Spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, NovaTheme.Spacing.xl)
    }
}
