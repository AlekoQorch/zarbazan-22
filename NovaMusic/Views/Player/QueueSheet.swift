import SwiftUI

struct QueueSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let current = appState.player.currentSong {
                    Section("Now Playing") {
                        SongRowView(song: current, isPlaying: true) {
                            dismiss()
                        }
                        .listRowBackground(Color.novaSurface)
                    }
                }

                Section("Up Next") {
                    if appState.player.upcomingSongs.isEmpty {
                        Text("Queue is empty")
                            .foregroundStyle(Color.novaTextSecondary)
                    } else {
                        ForEach(Array(appState.player.upcomingSongs.enumerated()), id: \.element.id) { index, song in
                            SongRowView(song: song) {
                                let absoluteIndex = appState.player.queueIndex + 1 + index
                                appState.player.play(songs: appState.player.queue, startAt: absoluteIndex)
                            }
                            .listRowBackground(Color.novaSurface)
                        }
                        .onDelete { offsets in
                            let base = appState.player.queueIndex + 1
                            let absolute = IndexSet(offsets.map { $0 + base })
                            appState.player.removeFromQueue(at: absolute)
                        }
                        .onMove { from, to in
                            let base = appState.player.queueIndex + 1
                            let adjustedFrom = IndexSet(from.map { $0 + base })
                            let adjustedTo = to + base
                            appState.player.moveQueue(fromOffsets: adjustedFrom, toOffset: adjustedTo)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.novaBackground)
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
