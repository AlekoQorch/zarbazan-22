import SwiftUI

struct PlaylistsView: View {
    @Environment(AppState.self) private var appState
    @State private var showCreate = false
    @State private var newName = ""
    @State private var renameTarget: Playlist?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                if appState.playlists.playlists.isEmpty {
                    ContentUnavailableView(
                        "No Playlists",
                        systemImage: "rectangle.stack",
                        description: Text("Create a playlist to organize your music.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(appState.playlists.playlists, id: \.id) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlist: playlist)
                                .environment(appState)
                        } label: {
                            HStack(spacing: NovaTheme.Spacing.sm) {
                                playlistArtwork(playlist)
                                    .frame(width: 56, height: 56)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(playlist.name)
                                        .foregroundStyle(Color.novaTextPrimary)
                                    Text("\(playlist.songCount) songs · \(DurationFormatter.longString(from: playlist.totalDuration))")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.novaTextSecondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
                        .contextMenu {
                            Button("Rename") {
                                renameTarget = playlist
                                renameText = playlist.name
                            }
                            Button("Play") {
                                let songs = playlist.songs
                                guard !songs.isEmpty else { return }
                                appState.playlists.markPlayed(playlist)
                                appState.player.play(songs: songs)
                                appState.player.showsNowPlaying = true
                            }
                            Button("Shuffle") {
                                var songs = playlist.songs
                                guard !songs.isEmpty else { return }
                                songs.shuffle()
                                appState.playlists.markPlayed(playlist)
                                appState.player.play(songs: songs)
                                appState.player.showsNowPlaying = true
                            }
                            Button("Delete", role: .destructive) {
                                appState.playlists.delete(playlist)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            appState.playlists.delete(appState.playlists.playlists[index])
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.novaBackground)
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newName = ""
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Playlist", isPresented: $showCreate) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    _ = appState.playlists.createPlaylist(named: newName)
                }
            }
            .alert("Rename Playlist", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) { renameTarget = nil }
                Button("Save") {
                    if let playlist = renameTarget {
                        appState.playlists.rename(playlist, to: renameText)
                    }
                    renameTarget = nil
                }
            }
            .onAppear { appState.playlists.refresh() }
        }
    }

    @ViewBuilder
    private func playlistArtwork(_ playlist: Playlist) -> some View {
        if let id = playlist.artworkSongID, let song = appState.library.song(id: id) {
            ArtworkView(song: song)
        } else if let song = playlist.songs.first {
            ArtworkView(song: song)
        } else {
            PlaceholderArtwork(title: playlist.name, artist: "")
                .clipShape(RoundedRectangle(cornerRadius: NovaTheme.Radius.artwork, style: .continuous))
        }
    }
}

struct PlaylistDetailView: View {
    @Environment(AppState.self) private var appState
    let playlist: Playlist
    @State private var showAddSongs = false

    var body: some View {
        List {
            Section {
                VStack(spacing: NovaTheme.Spacing.md) {
                    Text(playlist.name)
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.novaTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(playlist.songCount) songs")
                        .foregroundStyle(Color.novaTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: NovaTheme.Spacing.sm) {
                        Button {
                            let songs = playlist.songs
                            guard !songs.isEmpty else { return }
                            appState.playlists.markPlayed(playlist)
                            appState.player.play(songs: songs)
                            appState.player.showsNowPlaying = true
                        } label: {
                            Label("Play", systemImage: "play.fill")
                        }
                        .buttonStyle(NovaPrimaryButtonStyle())

                        Button {
                            var songs = playlist.songs
                            guard !songs.isEmpty else { return }
                            songs.shuffle()
                            appState.playlists.markPlayed(playlist)
                            appState.player.play(songs: songs)
                            appState.player.showsNowPlaying = true
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                        }
                        .buttonStyle(NovaSecondaryButtonStyle())
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                ForEach(playlist.songs, id: \.id) { song in
                    SongRowView(song: song, isPlaying: appState.player.currentSong?.id == song.id) {
                        appState.player.play(song: song, in: playlist.songs)
                    }
                    .listRowBackground(Color.clear)
                }
                .onDelete { indexSet in
                    let songs = indexSet.compactMap { playlist.songs[safe: $0] }
                    appState.playlists.remove(songs: songs, from: playlist)
                }
                .onMove { from, to in
                    appState.playlists.moveSong(in: playlist, fromOffsets: from, toOffset: to)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.novaBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    EditButton()
                    Button { showAddSongs = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSongs) {
            SongPickerSheet { songs in
                appState.playlists.add(songs: songs, to: playlist)
            }
            .environment(appState)
        }
    }
}

struct AddToPlaylistSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let songs: [Song]
    @State private var newName = ""
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            List {
                Button {
                    showCreate = true
                } label: {
                    Label("New Playlist", systemImage: "plus")
                }
                ForEach(appState.playlists.playlists, id: \.id) { playlist in
                    Button(playlist.name) {
                        appState.playlists.add(songs: songs, to: playlist)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("New Playlist", isPresented: $showCreate) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    let playlist = appState.playlists.createPlaylist(named: newName, songs: songs)
                    _ = playlist
                    dismiss()
                }
            }
        }
    }
}

struct SongPickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    var onPick: ([Song]) -> Void
    @State private var selected: Set<UUID> = []
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered, id: \.id) { song in
                    Button {
                        if selected.contains(song.id) {
                            selected.remove(song.id)
                        } else {
                            selected.insert(song.id)
                        }
                    } label: {
                        HStack {
                            ArtworkView(song: song).frame(width: 44, height: 44)
                            VStack(alignment: .leading) {
                                Text(song.title).foregroundStyle(Color.novaTextPrimary)
                                Text(song.artist).font(.caption).foregroundStyle(Color.novaTextSecondary)
                            }
                            Spacer()
                            Image(systemName: selected.contains(song.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected.contains(song.id) ? Color.novaAccent : Color.novaTextSecondary)
                        }
                    }
                }
            }
            .searchable(text: $query)
            .navigationTitle("Add Songs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let songs = appState.library.songs.filter { selected.contains($0.id) }
                        onPick(songs)
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
    }

    private var filtered: [Song] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return appState.library.sortedSongs }
        return appState.library.songs.filter {
            $0.title.localizedCaseInsensitiveContains(q)
            || $0.artist.localizedCaseInsensitiveContains(q)
            || $0.album.localizedCaseInsensitiveContains(q)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
