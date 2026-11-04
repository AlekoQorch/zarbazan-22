import SwiftUI

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @State private var showImporter = false
    @State private var showSort = false
    @State private var editSong: Song?
    @State private var multiSelect = false
    @State private var selectedIDs: Set<UUID> = []

    var body: some View {
        @Bindable var state = appState
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $state.librarySegment) {
                    ForEach(LibrarySegment.allCases) { segment in
                        Text(segment.title).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, NovaTheme.Spacing.md)
                .padding(.vertical, NovaTheme.Spacing.sm)

                content
            }
            .novaScreen()
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if multiSelect {
                        Button("Cancel") {
                            multiSelect = false
                            selectedIDs.removeAll()
                        }
                    } else {
                        Menu {
                            ForEach(PlaybackSort.allCases) { sort in
                                Button(sort.label) { appState.library.sort = sort }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        if multiSelect {
                            Button(role: .destructive) {
                                let songs = appState.library.songs.filter { selectedIDs.contains($0.id) }
                                appState.library.deleteSongs(songs)
                                selectedIDs.removeAll()
                                multiSelect = false
                            } label: {
                                Image(systemName: "trash")
                            }
                            .disabled(selectedIDs.isEmpty)
                        } else {
                            Button {
                                multiSelect.toggle()
                            } label: {
                                Image(systemName: "checkmark.circle")
                            }
                            Button { showImporter = true } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showImporter) {
                MusicDocumentPicker { urls in
                    showImporter = false
                    Task { await appState.importer.importFiles(from: urls) }
                }
                .ignoresSafeArea()
            }
            .sheet(item: $editSong) { song in
                MetadataEditorView(song: song)
                    .environment(appState)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appState.librarySegment {
        case .songs:
            songList(appState.library.sortedSongs)
        case .albums:
            albumList
        case .artists:
            artistList
        case .favorites:
            songList(appState.library.favorites)
        case .recent:
            List {
                Section("Recently Added") {
                    ForEach(appState.library.recentlyAdded, id: \.id) { song in
                        songRow(song, context: appState.library.recentlyAdded)
                    }
                }
                Section("Recently Played") {
                    ForEach(appState.library.recentlyPlayed, id: \.id) { song in
                        songRow(song, context: appState.library.recentlyPlayed)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .overlay {
                if appState.library.recentlyAdded.isEmpty && appState.library.recentlyPlayed.isEmpty {
                    emptyState("No recent activity")
                }
            }
        }
    }

    private func songList(_ songs: [Song]) -> some View {
        List {
            ForEach(songs, id: \.id) { song in
                songRow(song, context: songs)
            }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if songs.isEmpty {
                emptyState(appState.librarySegment == .favorites ? "No favorites yet" : "No songs yet")
            }
        }
    }

    @ViewBuilder
    private func songRow(_ song: Song, context: [Song]) -> some View {
        HStack {
            if multiSelect {
                Image(systemName: selectedIDs.contains(song.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedIDs.contains(song.id) ? Color.novaAccent : Color.novaTextSecondary)
                    .onTapGesture {
                        if selectedIDs.contains(song.id) {
                            selectedIDs.remove(song.id)
                        } else {
                            selectedIDs.insert(song.id)
                        }
                    }
            }
            SongRowView(
                song: song,
                isPlaying: appState.player.currentSong?.id == song.id && appState.player.isPlaying
            ) {
                if multiSelect {
                    if selectedIDs.contains(song.id) {
                        selectedIDs.remove(song.id)
                    } else {
                        selectedIDs.insert(song.id)
                    }
                } else {
                    appState.player.play(song: song, in: context)
                }
            }
            .contextMenu {
                Button("Edit Metadata") { editSong = song }
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparatorTint(Color.novaSeparator)
    }

    private var albumList: some View {
        List {
            ForEach(appState.library.albums) { album in
                NavigationLink {
                    AlbumDetailView(album: album)
                        .environment(appState)
                } label: {
                    HStack(spacing: NovaTheme.Spacing.sm) {
                        ArtworkView(song: album.artworkSong)
                            .frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(album.name)
                                .foregroundStyle(Color.novaTextPrimary)
                            Text("\(album.artist) · \(album.songs.count) songs")
                                .font(.subheadline)
                                .foregroundStyle(Color.novaTextSecondary)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if appState.library.albums.isEmpty { emptyState("No albums yet") }
        }
    }

    private var artistList: some View {
        List {
            ForEach(appState.library.artists) { artist in
                NavigationLink {
                    ArtistDetailView(artist: artist)
                        .environment(appState)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(artist.name)
                            .foregroundStyle(Color.novaTextPrimary)
                        Text("\(artist.songs.count) songs · \(artist.albumCount) albums")
                            .font(.subheadline)
                            .foregroundStyle(Color.novaTextSecondary)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if appState.library.artists.isEmpty { emptyState("No artists yet") }
        }
    }

    private func emptyState(_ message: String) -> some View {
        ContentUnavailableView {
            Label(message, systemImage: "music.note")
        } description: {
            Text("Import music from Files to build your library.")
        } actions: {
            Button("Import Music") { showImporter = true }
                .buttonStyle(.borderedProminent)
                .tint(Color.novaAccent)
        }
    }
}
