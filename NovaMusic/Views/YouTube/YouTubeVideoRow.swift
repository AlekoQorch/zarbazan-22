import SwiftUI

struct YouTubeVideoRow: View {
    let video: YouTubeVideo
    var isFavorite: Bool = false
    var onTap: () -> Void
    var onFavorite: (() -> Void)? = nil
    var onAddToPlaylist: (() -> Void)? = nil

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: video.thumbnailURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Color.novaSurfaceElevated
                                .overlay {
                                    Image(systemName: "play.rectangle.fill")
                                        .foregroundStyle(Color.novaTextSecondary)
                                }
                        case .empty:
                            Color.novaSurfaceElevated
                                .overlay { ProgressView().tint(Color.novaAccent) }
                        @unknown default:
                            Color.novaSurfaceElevated
                        }
                    }
                    .frame(width: 128, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text(video.durationText)
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .padding(4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.novaTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(video.channelTitle)
                        .font(.caption)
                        .foregroundStyle(Color.novaTextSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onFavorite {
                Button {
                    onFavorite()
                } label: {
                    Label(isFavorite ? "Remove Favorite" : "Favorite", systemImage: isFavorite ? "heart.slash" : "heart")
                }
            }
            if let onAddToPlaylist {
                Button {
                    onAddToPlaylist()
                } label: {
                    Label("Add to Playlist", systemImage: "text.badge.plus")
                }
            }
        }
    }
}
