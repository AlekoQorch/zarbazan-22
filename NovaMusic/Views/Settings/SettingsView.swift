import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showSleepTimer = false
    @State private var confirmClearLibrary = false
    @State private var youtubeAPIKeyDraft = YouTubeConfig.apiKey ?? ""
    @State private var youtubeKeySaved = false

    var body: some View {
        @Bindable var state = appState
        NavigationStack {
            List {
                Section {
                    SecureField("YouTube Data API v3 key", text: $youtubeAPIKeyDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    HStack {
                        Button(youtubeKeySaved ? "Saved" : "Save Key") {
                            YouTubeConfig.saveUserAPIKey(youtubeAPIKeyDraft)
                            youtubeKeySaved = true
                        }
                        .disabled(youtubeAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Spacer()
                        if YouTubeConfig.isConfigured {
                            Label("Configured", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.novaAccent)
                        }
                    }
                    if YouTubeConfig.isConfigured {
                        Button("Clear Key", role: .destructive) {
                            YouTubeConfig.clearUserAPIKey()
                            youtubeAPIKeyDraft = ""
                            youtubeKeySaved = false
                        }
                    }
                } header: {
                    Text("YouTube")
                } footer: {
                    Text("Required for real YouTube search. Create a key in Google Cloud → enable YouTube Data API v3. Playback uses the official embedded player only — videos are not downloaded. See docs/YOUTUBE_SETUP.md.")
                }

                Section("Appearance") {
                    Picker("Theme", selection: $state.settings.appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .onChange(of: state.settings.appearance) { _, _ in
                        appState.saveSettings()
                    }
                }

                Section("Playback") {
                    Toggle("Resume on Launch", isOn: $state.settings.resumePlaybackOnLaunch)
                        .onChange(of: state.settings.resumePlaybackOnLaunch) { _, _ in
                            appState.saveSettings()
                        }
                    Toggle("Remember Position", isOn: $state.settings.rememberPosition)
                        .onChange(of: state.settings.rememberPosition) { _, _ in
                            appState.saveSettings()
                        }
                    Toggle("Haptics", isOn: $state.settings.hapticFeedback)
                        .onChange(of: state.settings.hapticFeedback) { _, _ in
                            appState.saveSettings()
                        }
                }

                Section {
                    Picker("Equalizer", selection: $state.settings.equalizerPreset) {
                        ForEach(EqualizerPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .onChange(of: state.settings.equalizerPreset) { _, newValue in
                        appState.player.equalizerPreset = newValue
                        appState.saveSettings()
                    }

                    if !appState.player.equalizerAvailable,
                       let reason = appState.player.equalizerUnavailableReason,
                       appState.player.equalizerPreset != .off {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(Color.novaTextSecondary)
                    }
                } header: {
                    Text("Audio")
                } footer: {
                    Text("Presets are stored with your settings. Software EQ availability depends on the active audio route.")
                }

                Section("Sleep Timer") {
                    if appState.sleepTimer.isActive {
                        HStack {
                            Text(appState.sleepTimer.option?.title ?? "Active")
                            Spacer()
                            if appState.sleepTimer.endsAt != nil {
                                Text(appState.sleepTimer.remainingFormatted)
                                    .monospacedDigit()
                                    .foregroundStyle(Color.novaAccent)
                            } else {
                                Text("End of track")
                                    .foregroundStyle(Color.novaAccent)
                            }
                        }
                        Button("Cancel Timer", role: .destructive) {
                            appState.sleepTimer.cancel()
                        }
                    } else {
                        Button("Set Sleep Timer") { showSleepTimer = true }
                    }
                }

                Section("Library") {
                    LabeledContent("Songs", value: "\(appState.library.songs.count)")
                    LabeledContent("Playlists", value: "\(appState.playlists.playlists.count)")
                    LabeledContent(
                        "Listening Time",
                        value: DurationFormatter.longString(from: appState.library.totalListeningTime)
                    )
                    NavigationLink("Listening Stats") {
                        ListeningStatsView()
                            .environment(appState)
                    }
                    Button("Delete All Songs", role: .destructive) {
                        confirmClearLibrary = true
                    }
                }

                Section("About") {
                    LabeledContent("NOVA MUSIC", value: "1.0.0")
                    Text("A premium offline music player. Your files stay on your device.")
                        .font(.footnote)
                        .foregroundStyle(Color.novaTextSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.novaBackground)
            .navigationTitle("Settings")
            .onAppear {
                youtubeAPIKeyDraft = UserDefaults.standard.string(forKey: YouTubeConfig.userDefaultsKey) ?? ""
            }
            .onChange(of: youtubeAPIKeyDraft) { _, _ in
                youtubeKeySaved = false
            }
            .sheet(isPresented: $showSleepTimer) {
                SleepTimerSheet()
                    .environment(appState)
                    .presentationDetents([.medium])
            }
            .confirmationDialog(
                "Delete all imported songs? This cannot be undone.",
                isPresented: $confirmClearLibrary,
                titleVisibility: .visible
            ) {
                Button("Delete All Songs", role: .destructive) {
                    appState.library.deleteSongs(appState.library.songs)
                    appState.player.stop()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

struct SleepTimerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(SleepTimerOption.presets) { option in
                    Button(option.title) {
                        appState.sleepTimer.schedule(option)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct ListeningStatsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent(
                    "Total Listening",
                    value: DurationFormatter.longString(from: appState.library.totalListeningTime)
                )
                LabeledContent("Tracks Played", value: "\(appState.library.songs.filter { $0.playCount > 0 }.count)")
            }

            Section("Most Played") {
                if appState.library.mostPlayed.isEmpty {
                    Text("Play some music to see stats.")
                        .foregroundStyle(Color.novaTextSecondary)
                } else {
                    ForEach(appState.library.mostPlayed, id: \.id) { song in
                        HStack {
                            ArtworkView(song: song).frame(width: 44, height: 44)
                            VStack(alignment: .leading) {
                                Text(song.title)
                                Text(song.artist)
                                    .font(.caption)
                                    .foregroundStyle(Color.novaTextSecondary)
                            }
                            Spacer()
                            Text("\(song.playCount)×")
                                .foregroundStyle(Color.novaAccent)
                                .monospacedDigit()
                        }
                    }
                }
            }

            Section("Recently Played") {
                ForEach(appState.library.recentlyPlayed, id: \.id) { song in
                    SongRowView(song: song) {
                        appState.player.play(song: song, in: appState.library.recentlyPlayed)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.novaBackground)
        .navigationTitle("Stats")
    }
}
