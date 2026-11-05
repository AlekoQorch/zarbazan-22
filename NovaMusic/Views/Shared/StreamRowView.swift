import SwiftUI

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
