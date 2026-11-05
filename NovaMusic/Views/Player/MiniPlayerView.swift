import SwiftUI

struct MiniPlayerView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.hasMiniPlayer {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    let progress: Double = {
                        if appState.youtubeNowPlaying != nil { return 0 }
                        guard appState.player.duration > 0 else { return 0 }
                        return appState.player.currentTime / appState.player.duration
                    }()
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
                        if appState.youtubeNowPlaying != nil {
                            appState.showsYouTubePlayer = true
                        } else {
                            appState.player.showsNowPlaying = true
                        }
                    } label: {
                        HStack(spacing: NovaTheme.Spacing.sm) {
                            artwork
                                .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(titleText)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.novaTextPrimary)
                                    .lineLimit(1)
                                Text(artistText)
                                    .font(.caption)
                                    .foregroundStyle(Color.novaTextSecondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)

                    if appState.youtubeNowPlaying == nil {
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
                    } else {
                        Button {
                            appState.showsYouTubePlayer = true
                        } label: {
                            Image(systemName: "play.rectangle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.novaTextPrimary)
                                .frame(width: 40, height: 40)
                        }

                        Button {
                            appState.stopYouTube()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.novaTextPrimary)
                                .frame(width: 40, height: 40)
                        }
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

    private var titleText: String {
        appState.youtubeNowPlaying?.title ?? appState.player.nowPlayingTitle
    }

    private var artistText: String {
        if let yt = appState.youtubeNowPlaying {
            return yt.channelTitle
        }
        return appState.player.nowPlayingArtist
    }

    @ViewBuilder
    private var artwork: some View {
        if let yt = appState.youtubeNowPlaying {
            RemoteArtworkView(
                url: yt.thumbnailURL,
                title: yt.title,
                artist: yt.channelTitle,
                cornerRadius: 8
            )
        } else if let song = appState.player.currentSong {
            ArtworkView(song: song, cornerRadius: 8)
        } else if let stream = appState.player.currentStream {
            RemoteArtworkView(
                url: stream.artworkURL,
                title: stream.title,
                artist: stream.artist,
                cornerRadius: 8
            )
        }
    }
}
