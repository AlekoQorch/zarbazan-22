import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var query = ""
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if !appState.searchHistory.isEmpty {
                        Section {
                            ForEach(appState.searchHistory, id: \.self) { term in
                                Button {
                                    query = term
                                } label: {
                                    Label(term, systemImage: "clock.arrow.circlepath")
                                        .foregroundStyle(Color.novaTextPrimary)
                                }
                            }
                            Button("Clear History", role: .destructive) {
                                appState.clearSearchHistory()
                            }
                        } header: {
                            Text("Recent Searches")
                        }
                    } else {
                        ContentUnavailableView(
                            "Search your library",
                            systemImage: "magnifyingglass",
                            description: Text("Find songs by title, artist, or album.")
                        )
                        .listRowBackground(Color.clear)
                    }
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .listRowBackground(Color.clear)
                } else {
                    Section("Songs") {
                        ForEach(results, id: \.id) { song in
                            SongRowView(
                                song: song,
                                isPlaying: appState.player.currentSong?.id == song.id
                            ) {
                                appState.addSearchHistory(query)
                                appState.player.play(song: song, in: results)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.novaBackground)
            .navigationTitle("Search")
            .searchable(text: $query, isPresented: $isSearching, prompt: "Songs, artists, albums")
            .onSubmit(of: .search) {
                appState.addSearchHistory(query)
            }
        }
    }

    private var results: [Song] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return appState.library.songs.filter {
            $0.title.localizedCaseInsensitiveContains(q)
            || $0.artist.localizedCaseInsensitiveContains(q)
            || $0.album.localizedCaseInsensitiveContains(q)
            || $0.genre.localizedCaseInsensitiveContains(q)
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}
