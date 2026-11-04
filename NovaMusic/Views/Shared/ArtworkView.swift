import SwiftUI
import UIKit

struct ArtworkView: View {
    let song: Song?
    var cornerRadius: CGFloat = NovaTheme.Radius.artwork
    var placeholderHue: Double = 0.55

    @Environment(AppState.self) private var appState

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                if let song,
                   let url = appState.library.artworkURL(for: song),
                   let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    PlaceholderArtwork(title: song?.title ?? "Nova", artist: song?.artist ?? "", hue: placeholderHue)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct PlaceholderArtwork: View {
    let title: String
    let artist: String
    var hue: Double = 0.55

    private var seed: Double {
        let base = (title + artist).utf8.reduce(0) { $0 &+ Int($1) }
        return Double(base % 360) / 360.0
    }

    var body: some View {
        let h = (hue + seed).truncatingRemainder(dividingBy: 1)
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: h, saturation: 0.45, brightness: 0.35),
                    Color(hue: (h + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.55, brightness: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}

struct ArtworkImage: View {
    let url: URL?
    let title: String
    let artist: String
    var cornerRadius: CGFloat = NovaTheme.Radius.artwork

    var body: some View {
        Group {
            if let url, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                PlaceholderArtwork(title: title, artist: artist)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Remote (HTTP) artwork for streamed tracks.
struct RemoteArtworkView: View {
    let url: URL?
    let title: String
    let artist: String
    var cornerRadius: CGFloat = NovaTheme.Radius.artwork

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        PlaceholderArtwork(title: title, artist: artist)
                    case .empty:
                        PlaceholderArtwork(title: title, artist: artist)
                            .overlay { ProgressView().tint(.white) }
                    @unknown default:
                        PlaceholderArtwork(title: title, artist: artist)
                    }
                }
            } else {
                PlaceholderArtwork(title: title, artist: artist)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .aspectRatio(1, contentMode: .fit)
    }
}
