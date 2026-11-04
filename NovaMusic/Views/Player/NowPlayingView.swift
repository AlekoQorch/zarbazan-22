import SwiftUI
import UIKit

struct NowPlayingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var showQueue = false
    @State private var showAddToPlaylist = false
    @State private var seekValue: Double = 0
    @State private var artworkScale: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            let song = appState.player.currentSong
            ZStack {
                artworkBackground(song: song)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    grabber
                        .padding(.top, 10)

                    Spacer(minLength: NovaTheme.Spacing.md)

                    ArtworkView(song: song, cornerRadius: NovaTheme.Radius.artworkLarge)
                        .frame(width: min(geo.size.width - 48, 360))
                        .scaleEffect(artworkScale)
                        .shadow(color: .black.opacity(0.45), radius: 30, y: 18)
                        .padding(.horizontal, NovaTheme.Spacing.lg)
                        .animation(NovaTheme.Motion.artwork, value: appState.player.isPlaying)

                    Spacer(minLength: NovaTheme.Spacing.lg)

                    metadata(song: song)
                        .padding(.horizontal, NovaTheme.Spacing.lg)

                    seekBar
                        .padding(.horizontal, NovaTheme.Spacing.lg)
                        .padding(.top, NovaTheme.Spacing.lg)

                    transportControls
                        .padding(.top, NovaTheme.Spacing.lg)
                        .padding(.horizontal, NovaTheme.Spacing.md)

                    secondaryControls(song: song)
                        .padding(.top, NovaTheme.Spacing.lg)
                        .padding(.horizontal, NovaTheme.Spacing.lg)

                    volumeBar
                        .padding(.horizontal, NovaTheme.Spacing.lg)
                        .padding(.top, NovaTheme.Spacing.md)
                        .padding(.bottom, NovaTheme.Spacing.xl)
                }
                .offset(y: dragOffset)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 140 {
                            dismiss()
                        } else {
                            withAnimation(NovaTheme.Motion.gentle) { dragOffset = 0 }
                        }
                    }
            )
        }
        .onAppear {
            seekValue = appState.player.currentTime
            artworkScale = appState.player.isPlaying ? 1 : 0.94
        }
        .onChange(of: appState.player.isPlaying) { _, playing in
            withAnimation(NovaTheme.Motion.artwork) {
                artworkScale = playing ? 1 : 0.94
            }
        }
        .onChange(of: appState.player.currentTime) { _, time in
            if !appState.player.isSeeking {
                seekValue = time
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueSheet()
                .environment(appState)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAddToPlaylist) {
            if let song = appState.player.currentSong {
                AddToPlaylistSheet(songs: [song])
                    .environment(appState)
            }
        }
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.novaTextSecondary.opacity(0.45))
            .frame(width: 40, height: 5)
    }

    @ViewBuilder
    private func artworkBackground(song: Song?) -> some View {
        ZStack {
            Color.novaBackground
            if let song,
               let url = appState.library.artworkURL(for: song),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 48)
                    .opacity(0.45)
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color.novaBackground.opacity(0.35),
                                Color.novaBackground.opacity(0.92)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            } else {
                LinearGradient(
                    colors: [
                        Color.novaAccent.opacity(0.28),
                        Color.black.opacity(0.95),
                        Color.novaBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    @ViewBuilder
    private func metadata(song: Song?) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(song?.title ?? "Not Playing")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.novaTextPrimary)
                    .lineLimit(2)
                Text(song?.artist ?? "")
                    .font(.title3)
                    .foregroundStyle(Color.novaTextSecondary)
                    .lineLimit(1)
                Text(song?.album ?? "")
                    .font(.subheadline)
                    .foregroundStyle(Color.novaTextSecondary.opacity(0.85))
                    .lineLimit(1)
            }
            Spacer()
            if let song {
                Button {
                    appState.library.toggleFavorite(song)
                } label: {
                    Image(systemName: song.isFavorite ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(song.isFavorite ? Color.novaAccent : Color.novaTextPrimary)
                        .frame(width: 44, height: 44)
                }
            }
        }
    }

    private var seekBar: some View {
        VStack(spacing: 8) {
            Slider(
                value: $seekValue,
                in: 0...max(appState.player.duration, 1),
                onEditingChanged: { editing in
                    if editing {
                        appState.player.beginSeek()
                    } else {
                        appState.player.endSeek(to: seekValue)
                    }
                }
            )
            .tint(Color.novaAccent)

            HStack {
                Text(DurationFormatter.string(from: seekValue))
                Spacer()
                Text(DurationFormatter.string(from: appState.player.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(Color.novaTextSecondary)
        }
    }

    private var transportControls: some View {
        HStack(spacing: 0) {
            Button {
                appState.player.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundStyle(appState.player.shuffleEnabled ? Color.novaAccent : Color.novaTextSecondary)
                    .frame(maxWidth: .infinity)
            }

            Button {
                appState.player.skipPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.novaTextPrimary)
                    .frame(maxWidth: .infinity)
            }

            Button {
                appState.player.togglePlayPause()
            } label: {
                Image(systemName: appState.player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 72))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.novaTextPrimary)
                    .frame(maxWidth: .infinity)
            }

            Button {
                appState.player.skipNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.novaTextPrimary)
                    .frame(maxWidth: .infinity)
            }

            Button {
                appState.player.cycleRepeatMode()
            } label: {
                Image(systemName: appState.player.repeatMode.systemImage)
                    .font(.title3)
                    .foregroundStyle(appState.player.repeatMode == .off ? Color.novaTextSecondary : Color.novaAccent)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func secondaryControls(song: Song?) -> some View {
        HStack {
            Button {
                showAddToPlaylist = true
            } label: {
                Image(systemName: "text.badge.plus")
                    .font(.title3)
                    .foregroundStyle(Color.novaTextPrimary)
                    .frame(width: 44, height: 44)
            }
            .disabled(song == nil)

            Spacer()

            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .foregroundStyle(Color.novaTextPrimary)
                    .frame(width: 44, height: 44)
            }
        }
    }

    private var volumeBar: some View {
        HStack(spacing: NovaTheme.Spacing.sm) {
            Image(systemName: "speaker.fill")
                .foregroundStyle(Color.novaTextSecondary)
            Slider(
                value: Binding(
                    get: { Double(appState.player.volume) },
                    set: { appState.player.setVolume(Float($0)) }
                ),
                in: 0...1
            )
            .tint(Color.novaAccent)
            Image(systemName: "speaker.wave.3.fill")
                .foregroundStyle(Color.novaTextSecondary)
        }
        .font(.footnote)
    }
}
