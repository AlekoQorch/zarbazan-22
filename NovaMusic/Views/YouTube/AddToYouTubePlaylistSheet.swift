import SwiftUI

struct AddToYouTubePlaylistSheet: View {
    let video: YouTubeVideo
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section("New playlist") {
                    HStack {
                        TextField("Playlist name", text: $newName)
                        Button("Add") {
                            if let playlist = appState.youtube.createPlaylist(named: newName) {
                                appState.youtube.add(video, toPlaylist: playlist.id)
                                newName = ""
                                dismiss()
                            }
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("Your playlists") {
                    if appState.youtube.playlists.isEmpty {
                        Text("No playlists yet")
                            .foregroundStyle(Color.novaTextSecondary)
                    } else {
                        ForEach(appState.youtube.playlists) { playlist in
                            Button {
                                appState.youtube.add(video, toPlaylist: playlist.id)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.name)
                                            .foregroundStyle(Color.novaTextPrimary)
                                        Text("\(playlist.videos.count) videos")
                                            .font(.caption)
                                            .foregroundStyle(Color.novaTextSecondary)
                                    }
                                    Spacer()
                                    if playlist.videos.contains(where: { $0.id == video.id }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.novaAccent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.novaBackground)
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
