import SwiftUI
import PhotosUI
import UIKit

struct MetadataEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let song: Song

    @State private var title: String = ""
    @State private var artist: String = ""
    @State private var album: String = ""
    @State private var genre: String = ""
    @State private var trackNumber: Int = 0
    @State private var pickedItem: PhotosPickerItem?
    @State private var artworkData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Group {
                            if let artworkData, let image = UIImage(data: artworkData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                ArtworkView(song: song)
                            }
                        }
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: NovaTheme.Radius.artwork, style: .continuous))
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Label("Change Artwork", systemImage: "photo")
                    }
                }

                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Artist", text: $artist)
                    TextField("Album", text: $album)
                    TextField("Genre", text: $genre)
                    Stepper("Track \(trackNumber)", value: $trackNumber, in: 0...999)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.novaBackground)
            .navigationTitle("Edit Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appState.library.updateMetadata(
                            song: song,
                            title: title,
                            artist: artist,
                            album: album,
                            genre: genre,
                            trackNumber: trackNumber,
                            artworkData: artworkData
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                title = song.title
                artist = song.artist
                album = song.album
                genre = song.genre
                trackNumber = song.trackNumber
            }
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        artworkData = data
                    }
                }
            }
        }
    }
}
