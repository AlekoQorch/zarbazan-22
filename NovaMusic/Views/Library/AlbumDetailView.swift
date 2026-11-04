import SwiftUI

struct AlbumDetailView: View {
    let album: AlbumGroup
    @Environment(AppState.self) private var appState
    @State private var showPlaylistPicker = false

    var body: some View {
        List {
            Section {
                VStack(spacing: NovaTheme.Spacing.md) {
                    ArtworkView(song: album.artworkSong, cornerRadius: NovaTheme.Radius.artworkLarge)
                        .frame(width: 220, height: 220)
                        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
                        .frame(maxWidth: .infinity)

                    Text(album.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.novaTextPrimary)
                        .multilineTextAlignment(.center)
                    Text(album.artist)
                        .font(.body)
                        .foregroundStyle(Color.novaTextSecondary)

                    HStack(spacing: NovaTheme.Spacing.sm) {
                        Button {
                            appState.player.play(songs: album.songs, startAt: 0)
                            appState.player.showsNowPlaying = true
                        } label: {
                            Label("Play", systemImage: "play.fill")
                        }
                        .buttonStyle(NovaPrimaryButtonStyle())

                        Button {
                            var songs = album.songs
                            songs.shuffle()
                            appState.player.play(songs: songs, startAt: 0)
                            appState.player.showsNowPlaying = true
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                        }
                        .buttonStyle(NovaSecondaryButtonStyle())
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                ForEach(album.songs, id: \.id) { song in
                    SongRowView(
                        song: song,
                        showsAlbum: false,
                        isPlaying: appState.player.currentSong?.id == song.id
                    ) {
                        appState.player.play(song: song, in: album.songs)
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.novaBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showPlaylistPicker = true
                    } label: {
                        Label("Add Album to Playlist", systemImage: "text.badge.plus")
                    }
                    Button {
                        appState.player.addToQueue(album.songs)
                    } label: {
                        Label("Add to Queue", systemImage: "text.append")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showPlaylistPicker) {
            AddToPlaylistSheet(songs: album.songs)
                .environment(appState)
        }
    }
}

struct ArtistDetailView: View {
    let artist: ArtistGroup
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(artist.name)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.novaTextPrimary)
                    Text("\(artist.songs.count) songs · \(artist.albumCount) albums")
                        .foregroundStyle(Color.novaTextSecondary)

                    Button {
                        appState.player.play(songs: artist.songs, startAt: 0)
                        appState.player.showsNowPlaying = true
                    } label: {
                        Label("Play All", systemImage: "play.fill")
                    }
                    .buttonStyle(NovaPrimaryButtonStyle())
                    .padding(.top, 8)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section("Songs") {
                ForEach(artist.songs.sorted { $0.title < $1.title }, id: \.id) { song in
                    SongRowView(song: song, isPlaying: appState.player.currentSong?.id == song.id) {
                        appState.player.play(song: song, in: artist.songs)
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.novaBackground)
        .navigationBarTitleDisplayMode(.inline)
    }
}
