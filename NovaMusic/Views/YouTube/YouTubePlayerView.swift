import SwiftUI

/// Audio-focused YouTube now-playing shell (no iframe — AVPlayer owns playback).
struct YouTubePlayerView: View {
    let video: YouTubeVideo
    var onClose: (() -> Void)?

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showAddToPlaylist = false

    var body: some View {
        NavigationStack {
            VStack(spacing: NovaTheme.Spacing.lg) {
                RemoteArtworkView(
                    url: video.thumbnailURL,
                    title: video.title,
                    artist: video.channelTitle,
                    cornerRadius: 16
                )
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 320)
                .padding(.top, NovaTheme.Spacing.lg)

                VStack(alignment: .leading, spacing: 8) {
                    Text(video.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.novaTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(video.channelTitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.novaTextSecondary)
                    Text("YouTube audio · keeps playing when locked")
                        .font(.caption)
                        .foregroundStyle(Color.novaTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, NovaTheme.Spacing.md)

                HStack(spacing: NovaTheme.Spacing.md) {
                    Button {
                        _ = appState.youtube.toggleFavorite(video)
                    } label: {
                        Label(
                            appState.youtube.isFavorite(video) ? "Favorited" : "Favorite",
                            systemImage: appState.youtube.isFavorite(video) ? "heart.fill" : "heart"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.novaAccent)

                    Button {
                        showAddToPlaylist = true
                    } label: {
                        Label("Playlist", systemImage: "text.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, NovaTheme.Spacing.md)

                Spacer(minLength: 0)
            }
            .novaScreen()
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onClose?()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Stop", role: .destructive) {
                        appState.stopYouTube()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddToPlaylist) {
                AddToYouTubePlaylistSheet(video: video)
                    .environment(appState)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}
