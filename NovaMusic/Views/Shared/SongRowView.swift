import SwiftUI

struct SongRowView: View {
    let song: Song
    var showsAlbum: Bool = true
    var isPlaying: Bool = false
    var onTap: (() -> Void)?
    var trailingMenu: (() -> AnyView)?

    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: NovaTheme.Spacing.sm) {
                ArtworkView(song: song, cornerRadius: NovaTheme.Radius.medium)
                    .frame(width: 52, height: 52)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(isPlaying ? Color.novaAccent : Color.novaTextPrimary)
                        .lineLimit(1)
                    Text(showsAlbum ? song.displayArtistAlbum : song.artist)
                        .font(.subheadline)
                        .foregroundStyle(Color.novaTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if song.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(Color.novaAccent.opacity(0.85))
                }

                Text(song.formattedDuration)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.novaTextSecondary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            songContextMenu
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                appState.library.deleteSongs([song])
                if appState.player.currentSong?.id == song.id {
                    appState.player.skipNext()
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                appState.library.toggleFavorite(song)
            } label: {
                Label(song.isFavorite ? "Unfavorite" : "Favorite", systemImage: song.isFavorite ? "heart.slash" : "heart")
            }
            .tint(Color.novaAccent)
        }
    }

    @ViewBuilder
    private var songContextMenu: some View {
        Button {
            appState.player.play(song: song, in: appState.library.sortedSongs)
            appState.player.showsNowPlaying = true
        } label: {
            Label("Play", systemImage: "play.fill")
        }
        Button {
            appState.player.playNext([song])
        } label: {
            Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
        }
        Button {
            appState.player.addToQueue([song])
        } label: {
            Label("Add to Queue", systemImage: "text.append")
        }
        Button {
            appState.library.toggleFavorite(song)
        } label: {
            Label(song.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: song.isFavorite ? "heart.slash" : "heart")
        }
        Menu("Add to Playlist") {
            ForEach(appState.playlists.playlists) { playlist in
                Button(playlist.name) {
                    appState.playlists.add(songs: [song], to: playlist)
                }
            }
        }
    }
}
