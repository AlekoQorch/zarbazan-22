import SwiftUI

struct MiniPlayerView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if let song = appState.player.currentSong {
            VStack(spacing: 0) {
                // Progress hairline
                GeometryReader { geo in
                    let progress = appState.player.duration > 0
                        ? appState.player.currentTime / appState.player.duration
                        : 0
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.novaSeparator)
                        Rectangle()
                            .fill(Color.novaAccent)
                            .frame(width: max(0, geo.size.width * progress))
                    }
                }
                .frame(height: 2)

                HStack(spacing: NovaTheme.Spacing.sm) {
                    Button {
                        appState.player.showsNowPlaying = true
                    } label: {
                        HStack(spacing: NovaTheme.Spacing.sm) {
                            ArtworkView(song: song, cornerRadius: 8)
                                .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.novaTextPrimary)
                                    .lineLimit(1)
                                Text(song.artist)
                                    .font(.caption)
                                    .foregroundStyle(Color.novaTextSecondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        appState.player.togglePlayPause()
                    } label: {
                        Image(systemName: appState.player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(Color.novaTextPrimary)
                            .frame(width: 40, height: 40)
                    }

                    Button {
                        appState.player.skipNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .foregroundStyle(Color.novaTextPrimary)
                            .frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal, NovaTheme.Spacing.md)
                .padding(.vertical, NovaTheme.Spacing.xs)
            }
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.novaSeparator)
                    .frame(height: 0.5)
            }
        }
    }
}
