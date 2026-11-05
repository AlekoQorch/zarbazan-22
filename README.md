# NOVA MUSIC

Premium offline iPhone music player built with SwiftUI, AVFoundation, MediaPlayer, and SwiftData.

## Requirements

- Xcode 16+ (Swift 5.10+)
- iOS 17.0+
- macOS for building (this repository cannot be compiled on Linux)

## Open & Run

1. Open `NovaMusic.xcodeproj` in Xcode on a Mac.
2. Select an iPhone simulator or a physical device.
3. Set your Development Team under **Signing & Capabilities** if installing on a device.
4. Build & Run (`⌘R`).

Background Audio is configured via `UIBackgroundModes = audio` in `Info.plist`. Lock Screen / Control Center controls use `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`.

## Features

- Import MP3, M4A, AAC, WAV, AIFF, CAF (and FLAC when the system can decode it) from the Files app
- Persistent Application Support storage + SwiftData metadata
- Full playback engine: play/pause, next/prev, shuffle, repeat, seek, queue, resume
- Background playback, Lock Screen artwork & remote controls, interruption handling
- Home, Library, Playlists, Explore (YouTube / Free streams / Library), Settings
- **YouTube:** real search + background audio stream (lock/fold safe), favorites, playlists, search history
- Mini player + full-screen Now Playing with artwork-driven ambience
- Favorites, playlists, metadata editor, sleep timer, listening stats, equalizer presets (honest availability messaging)

## YouTube setup

YouTube search needs a **YouTube Data API v3** key. Full steps: [`docs/YOUTUBE_SETUP.md`](docs/YOUTUBE_SETUP.md).

Quick path: enable the API in Google Cloud → create an API key → paste it in the app under **Settings → YouTube**.

```bash
export YOUTUBE_DATA_API_KEY='your-key'
python3 scripts/test_youtube_api.py "lofi"
```

YouTube results play as an ephemeral audio/HLS stream in the system player (continues when locked). Nothing is saved for offline use.

## Architecture

```
NovaMusic/
  App/              # App entry, root navigation, AppState
  DesignSystem/     # Theme tokens
  Models/           # SwiftData Song, Playlist, PlaylistItem
  Managers/         # Audio, Import, Library, Playlist, Persistence, SleepTimer
  Views/            # Feature screens + shared UI
  Utilities/        # Storage, metadata, formatters
```

MVVM-style: `AppState` owns managers; views observe `@Observable` managers.

## Format notes

- Files are copied into Application Support — never kept as temporary security-scoped URLs.
- Duplicate imports are detected via SHA-256 of file contents.
- **FLAC:** iOS `AVAudioPlayer` does not universally decode FLAC. Files may import; playback succeeds only when the OS/decoder path supports them. Prefer ALAC (`.m4a`) for lossless on iOS.
- Software EQ presets are persisted; full parametric EQ via `AVAudioEngine` is noted as route-dependent in Settings.

## Design

See `DESIGN.md` for the visual reference lock (dark charcoal + cyan accent).
