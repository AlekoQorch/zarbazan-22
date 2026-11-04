import Foundation
import AVFoundation
import MediaPlayer
import UIKit

@MainActor
@Observable
final class AudioPlayerManager {
    private(set) var isPlaying = false
    private(set) var currentSong: Song?
    private(set) var currentStream: StreamTrack?
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var queue: [Song] = []
    private(set) var queueIndex: Int = 0
    private(set) var shuffleEnabled = false
    private(set) var repeatMode: RepeatMode = .off
    private(set) var volume: Float = 1.0
    private(set) var isSeeking = false
    private(set) var streamQueue: [StreamTrack] = []
    private(set) var streamIndex: Int = 0

    var showsNowPlaying = false

    var hasSomethingToPlay: Bool {
        currentSong != nil || currentStream != nil
    }

    var nowPlayingTitle: String {
        currentSong?.title ?? currentStream?.title ?? ""
    }

    var nowPlayingArtist: String {
        currentSong?.artist ?? currentStream?.artist ?? ""
    }

    private var player: AVAudioPlayer?
    private var remotePlayer: AVPlayer?
    private var remoteTimeObserver: Any?
    private var remoteEndObserver: NSObjectProtocol?
    private var displayLink: CADisplayLink?
    private var originalQueue: [Song] = []
    private var shuffleOrder: [Int] = []
    private var library: MusicLibraryManager?
    private let persistence: PersistenceManager
    nonisolated(unsafe) private var interruptionObserver: NSObjectProtocol?
    nonisolated(unsafe) private var routeObserver: NSObjectProtocol?
    private var lastPersistedAt: Date = .distantPast
    private var didRecordPlayForCurrent = false
    private var stopAtEndOfTrack = false

    // Equalizer (AVAudioEngine path reserved; AVAudioPlayer uses system EQ when available)
    var equalizerPreset: EqualizerPreset = .off {
        didSet { applyEqualizerNote() }
    }

    private(set) var equalizerAvailable = true
    private(set) var equalizerUnavailableReason: String?

    init(persistence: PersistenceManager = .shared) {
        self.persistence = persistence
        configureSession()
        setupRemoteCommands()
        setupNotifications()
        volume = AVAudioSession.sharedInstance().outputVolume
    }

    func bind(library: MusicLibraryManager) {
        self.library = library
    }

    // MARK: - Session

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetoothA2DP]
            )
            try session.setActive(true)
        } catch {
            print("NovaMusic: audio session error — \(error)")
        }
    }

    private func setupNotifications() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleInterruption(notification)
            }
        }

        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleRouteChange(notification)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            pause()
        case .ended:
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                play()
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        if reason == .oldDeviceUnavailable {
            // Headphones unplugged → pause (Apple HIG).
            pause()
        }
    }

    // MARK: - Playback control

    func play(songs: [Song], startAt index: Int = 0) {
        guard !songs.isEmpty else { return }
        stopRemotePlayback()
        currentStream = nil
        streamQueue = []
        originalQueue = songs
        shuffleOrder = Array(songs.indices)
        if shuffleEnabled {
            rebuildShuffleOrder(preferring: index)
            queue = shuffleOrder.map { songs[$0] }
            queueIndex = 0
        } else {
            queue = songs
            queueIndex = min(max(0, index), songs.count - 1)
        }
        loadAndPlay(queue[queueIndex], resumePosition: 0)
    }

    /// Stream online catalog tracks (Audius). Legal artist-uploaded music.
    func playStreams(_ tracks: [StreamTrack], startAt index: Int = 0) {
        guard !tracks.isEmpty else { return }
        player?.stop()
        player = nil
        currentSong = nil
        queue = []
        streamQueue = tracks
        streamIndex = min(max(0, index), tracks.count - 1)
        loadAndPlayStream(tracks[streamIndex])
    }

    func playStream(_ track: StreamTrack, in context: [StreamTrack]? = nil) {
        if let context, let idx = context.firstIndex(of: track) {
            playStreams(context, startAt: idx)
        } else {
            playStreams([track], startAt: 0)
        }
    }

    func play(song: Song, in context: [Song]? = nil) {
        if let context, let index = context.firstIndex(where: { $0.id == song.id }) {
            play(songs: context, startAt: index)
        } else if let existing = queue.firstIndex(where: { $0.id == song.id }) {
            queueIndex = existing
            loadAndPlay(queue[queueIndex], resumePosition: 0)
        } else {
            play(songs: [song], startAt: 0)
        }
    }

    func togglePlayPause() {
        if persistence.loadSettings().hapticFeedback {
            Haptics.light()
        }
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        configureSession()
        if let remotePlayer {
            remotePlayer.play()
            isPlaying = true
            updateNowPlayingElapsed()
            return
        }
        guard let player else {
            if let song = currentSong {
                loadAndPlay(song, resumePosition: currentTime)
            } else if let first = queue.first {
                loadAndPlay(first, resumePosition: 0)
            } else if let stream = currentStream {
                loadAndPlayStream(stream)
            }
            return
        }
        player.play()
        isPlaying = true
        startDisplayLink()
        updateNowPlayingElapsed()
        persistSnapshot()
    }

    func pause() {
        remotePlayer?.pause()
        player?.pause()
        isPlaying = false
        stopDisplayLink()
        updateNowPlayingElapsed()
        persistSnapshot()
    }

    func stop() {
        stopRemotePlayback()
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        currentStream = nil
        stopDisplayLink()
        clearNowPlaying()
        persistSnapshot()
    }

    func skipNext() {
        if !streamQueue.isEmpty {
            let next = streamIndex + 1
            if next < streamQueue.count {
                streamIndex = next
                loadAndPlayStream(streamQueue[streamIndex])
            } else if repeatMode == .all {
                streamIndex = 0
                loadAndPlayStream(streamQueue[streamIndex])
            } else {
                pause()
            }
            return
        }
        guard !queue.isEmpty else { return }
        if repeatMode == .one {
            seek(to: 0)
            play()
            return
        }
        let next = queueIndex + 1
        if next < queue.count {
            queueIndex = next
            loadAndPlay(queue[queueIndex], resumePosition: 0)
        } else if repeatMode == .all {
            queueIndex = 0
            loadAndPlay(queue[queueIndex], resumePosition: 0)
        } else {
            pause()
            currentTime = 0
        }
    }

    func skipPrevious() {
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        if !streamQueue.isEmpty {
            let prev = streamIndex - 1
            if prev >= 0 {
                streamIndex = prev
                loadAndPlayStream(streamQueue[streamIndex])
            } else if repeatMode == .all {
                streamIndex = streamQueue.count - 1
                loadAndPlayStream(streamQueue[streamIndex])
            } else {
                seek(to: 0)
            }
            return
        }
        guard !queue.isEmpty else { return }
        let prev = queueIndex - 1
        if prev >= 0 {
            queueIndex = prev
            loadAndPlay(queue[queueIndex], resumePosition: 0)
        } else if repeatMode == .all {
            queueIndex = queue.count - 1
            loadAndPlay(queue[queueIndex], resumePosition: 0)
        } else {
            seek(to: 0)
        }
    }

    func seek(to time: Double) {
        if let remotePlayer {
            let clamped = min(max(0, time), duration > 0 ? duration : time)
            remotePlayer.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
            currentTime = clamped
            updateNowPlayingElapsed()
            return
        }
        guard let player else { return }
        let clamped = min(max(0, time), player.duration)
        player.currentTime = clamped
        currentTime = clamped
        updateNowPlayingElapsed()
    }

    func beginSeek() {
        isSeeking = true
    }

    func endSeek(to time: Double) {
        seek(to: time)
        isSeeking = false
    }

    func setVolume(_ value: Float) {
        volume = min(max(0, value), 1)
        player?.volume = volume
        remotePlayer?.volume = volume
    }

    func toggleShuffle() {
        shuffleEnabled.toggle()
        guard !originalQueue.isEmpty else {
            persistSnapshot()
            return
        }
        let currentID = currentSong?.id
        if shuffleEnabled {
            let prefer = originalQueue.firstIndex(where: { $0.id == currentID }) ?? queueIndex
            rebuildShuffleOrder(preferring: prefer)
            queue = shuffleOrder.map { originalQueue[$0] }
            queueIndex = 0
        } else {
            queue = originalQueue
            if let currentID, let idx = queue.firstIndex(where: { $0.id == currentID }) {
                queueIndex = idx
            }
        }
        persistSnapshot()
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next
        persistSnapshot()
    }

    // MARK: - Queue management

    func addToQueue(_ songs: [Song]) {
        guard !songs.isEmpty else { return }
        if queue.isEmpty {
            play(songs: songs, startAt: 0)
            return
        }
        queue.append(contentsOf: songs)
        originalQueue.append(contentsOf: songs)
        persistSnapshot()
    }

    func playNext(_ songs: [Song]) {
        guard !songs.isEmpty else { return }
        if queue.isEmpty {
            play(songs: songs, startAt: 0)
            return
        }
        let insertAt = min(queueIndex + 1, queue.count)
        queue.insert(contentsOf: songs, at: insertAt)
        originalQueue.insert(contentsOf: songs, at: min(insertAt, originalQueue.count))
        persistSnapshot()
    }

    func removeFromQueue(at offsets: IndexSet) {
        let removingCurrent = offsets.contains(queueIndex)
        queue.remove(atOffsets: offsets)
        // Rebuild original roughly
        originalQueue = queue
        if queue.isEmpty {
            stop()
            currentSong = nil
            return
        }
        if removingCurrent {
            queueIndex = min(queueIndex, queue.count - 1)
            loadAndPlay(queue[queueIndex], resumePosition: 0)
        } else if let firstRemoved = offsets.first, firstRemoved < queueIndex {
            queueIndex -= offsets.filter { $0 < queueIndex }.count
        }
        persistSnapshot()
    }

    func moveQueue(fromOffsets: IndexSet, toOffset: Int) {
        let currentID = currentSong?.id
        queue.move(fromOffsets: fromOffsets, toOffset: toOffset)
        originalQueue = queue
        if let currentID, let idx = queue.firstIndex(where: { $0.id == currentID }) {
            queueIndex = idx
        }
        persistSnapshot()
    }

    var upcomingSongs: [Song] {
        guard queueIndex + 1 < queue.count else { return [] }
        return Array(queue[(queueIndex + 1)...])
    }

    // MARK: - Load

    private func loadAndPlay(_ song: Song, resumePosition: Double) {
        currentSong = song
        didRecordPlayForCurrent = false
        stopAtEndOfTrack = false

        let url = FileStorage.absoluteURL(forRelativePath: song.relativeFilePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("NovaMusic: missing file for \(song.title)")
            skipNext()
            return
        }

        do {
            try AVAudioSession.sharedInstance().setActive(true)
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = PlayerDelegateProxy.shared
            PlayerDelegateProxy.shared.owner = self
            newPlayer.volume = volume
            newPlayer.enableRate = true
            newPlayer.prepareToPlay()
            duration = newPlayer.duration > 0 ? newPlayer.duration : song.duration
            if resumePosition > 0, resumePosition < duration - 1 {
                newPlayer.currentTime = resumePosition
                currentTime = resumePosition
            } else {
                currentTime = 0
            }
            player = newPlayer
            newPlayer.play()
            isPlaying = true
            startDisplayLink()
            publishNowPlaying(for: song)
            persistSnapshot()
            applyEqualizerNote()
        } catch {
            print("NovaMusic: failed to play \(song.title) — \(error)")
            // Try next track rather than dying.
            let next = queueIndex + 1
            if next < queue.count {
                queueIndex = next
                loadAndPlay(queue[queueIndex], resumePosition: 0)
            }
        }
    }

    private func loadAndPlayStream(_ track: StreamTrack) {
        stopRemotePlayback()
        configureSession()
        currentStream = track
        currentSong = nil
        currentTime = 0
        duration = track.duration
        didRecordPlayForCurrent = true

        let item = AVPlayerItem(url: track.streamURL)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.volume = volume
        remotePlayer = newPlayer
        newPlayer.play()
        isPlaying = true

        remoteTimeObserver = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = time.seconds
                if let itemDuration = self.remotePlayer?.currentItem?.duration.seconds,
                   itemDuration.isFinite, itemDuration > 0 {
                    self.duration = itemDuration
                }
                self.isPlaying = self.remotePlayer?.rate ?? 0 > 0
                self.updateNowPlayingElapsed()
            }
        }

        remoteEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.skipNext()
            }
        }

        publishNowPlaying(stream: track)
    }

    private func stopRemotePlayback() {
        if let remoteTimeObserver, let remotePlayer {
            remotePlayer.removeTimeObserver(remoteTimeObserver)
        }
        remoteTimeObserver = nil
        if let remoteEndObserver {
            NotificationCenter.default.removeObserver(remoteEndObserver)
        }
        remoteEndObserver = nil
        remotePlayer?.pause()
        remotePlayer = nil
    }

    func playerDidFinish() {
        if stopAtEndOfTrack {
            stopAtEndOfTrack = false
            pause()
            return
        }
        if !didRecordPlayForCurrent, let song = currentSong {
            library?.recordPlay(for: song)
            didRecordPlayForCurrent = true
        }
        switch repeatMode {
        case .one:
            seek(to: 0)
            play()
        case .all, .off:
            let next = queueIndex + 1
            if next < queue.count {
                queueIndex = next
                loadAndPlay(queue[queueIndex], resumePosition: 0)
            } else if repeatMode == .all, !queue.isEmpty {
                queueIndex = 0
                loadAndPlay(queue[queueIndex], resumePosition: 0)
            } else {
                isPlaying = false
                currentTime = duration
                stopDisplayLink()
                persistSnapshot()
            }
        }
    }

    // MARK: - Display link

    private func startDisplayLink() {
        stopDisplayLink()
        let link = CADisplayLink(target: DisplayLinkProxy.shared, selector: #selector(DisplayLinkProxy.tick))
        DisplayLinkProxy.shared.owner = self
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    fileprivate func tick() {
        guard let player, !isSeeking else { return }
        currentTime = player.currentTime
        duration = player.duration > 0 ? player.duration : duration
        isPlaying = player.isPlaying

        if !didRecordPlayForCurrent, currentTime > 15, let song = currentSong {
            library?.recordPlay(for: song)
            didRecordPlayForCurrent = true
        }

        if Date().timeIntervalSince(lastPersistedAt) > 5 {
            persistSnapshot()
        }
        updateNowPlayingElapsed()
    }

    // MARK: - Now Playing / Remote

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipNext() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipPrevious() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
    }

    private func publishNowPlaying(for song: Song) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]

        if let artPath = song.artworkRelativePath {
            let url = FileStorage.absoluteURL(forRelativePath: artPath)
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                info[MPMediaItemPropertyArtwork] = artwork
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    private func publishNowPlaying(stream: StreamTrack) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: stream.title,
            MPMediaItemPropertyArtist: stream.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused

        guard let artworkURL = stream.artworkURL else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: artworkURL),
                  let image = UIImage(data: data) else { return }
            await MainActor.run {
                guard self.currentStream?.id == stream.id else { return }
                var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? info
                updated[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
            }
        }
    }

    private func updateNowPlayingElapsed() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPMediaItemPropertyPlaybackDuration] = duration
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    private func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Persistence

    func restoreIfNeeded() {
        let settings = persistence.loadSettings()
        equalizerPreset = settings.equalizerPreset
        let snapshot = persistence.loadPlaybackSnapshot()
        guard let library else { return }

        shuffleEnabled = snapshot.shuffleEnabled
        repeatMode = snapshot.repeatMode

        let songs = library.songs(ids: snapshot.queueSongIDs)
        guard !songs.isEmpty else { return }

        // Preserve order from snapshot
        let map = Dictionary(uniqueKeysWithValues: songs.map { ($0.id, $0) })
        let ordered = snapshot.queueSongIDs.compactMap { map[$0] }
        guard !ordered.isEmpty else { return }

        originalQueue = ordered
        queue = ordered
        queueIndex = min(max(0, snapshot.queueIndex), ordered.count - 1)

        let song = ordered[queueIndex]
        currentSong = song
        duration = song.duration
        currentTime = settings.rememberPosition ? snapshot.position : 0

        // Prepare player without auto-playing unless configured.
        let url = FileStorage.absoluteURL(forRelativePath: song.relativeFilePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = PlayerDelegateProxy.shared
            PlayerDelegateProxy.shared.owner = self
            newPlayer.volume = volume
            newPlayer.prepareToPlay()
            if settings.rememberPosition, snapshot.position > 0, snapshot.position < newPlayer.duration - 1 {
                newPlayer.currentTime = snapshot.position
                currentTime = snapshot.position
            }
            duration = newPlayer.duration
            player = newPlayer
            publishNowPlaying(for: song)
            if settings.resumePlaybackOnLaunch, snapshot.wasPlaying {
                play()
            }
        } catch {
            print("NovaMusic: restore failed — \(error)")
        }
    }

    private func persistSnapshot() {
        lastPersistedAt = Date()
        let snapshot = PlaybackSnapshot(
            currentSongID: currentSong?.id,
            position: currentTime,
            wasPlaying: isPlaying,
            queueSongIDs: queue.map(\.id),
            queueIndex: queueIndex,
            shuffleEnabled: shuffleEnabled,
            repeatMode: repeatMode,
            shuffleOrder: []
        )
        persistence.savePlaybackSnapshot(snapshot)
    }

    private func rebuildShuffleOrder(preferring index: Int) {
        var order = Array(originalQueue.indices)
        if order.isEmpty { shuffleOrder = []; return }
        order.shuffle()
        if let pos = order.firstIndex(of: index) {
            order.swapAt(0, pos)
        }
        shuffleOrder = order
    }

    private func applyEqualizerNote() {
        // AVAudioPlayer does not expose a full parametric EQ. We persist the preset
        // and surface availability honestly. For AirPlay/Bluetooth routes, system EQ
        // may also be unavailable — communicate that clearly.
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        let isExternal = outputs.contains {
            $0.portType == .airPlay || $0.portType == .bluetoothA2DP || $0.portType == .bluetoothLE
        }
        if equalizerPreset == .off {
            equalizerAvailable = true
            equalizerUnavailableReason = nil
        } else if isExternal {
            equalizerAvailable = false
            equalizerUnavailableReason = "Equalizer is unavailable on the current audio route (AirPlay/Bluetooth)."
        } else {
            // Honest limitation: software EQ requires AVAudioEngine; preset is saved for future engine path.
            equalizerAvailable = false
            equalizerUnavailableReason = "Software equalizer presets are saved and will apply when using the in-app engine route. System EQ may still be used from iOS Control Center."
        }
        var settings = persistence.loadSettings()
        settings.equalizerPreset = equalizerPreset
        persistence.saveSettings(settings)
    }

    func armStopAtEndOfTrack() {
        stopAtEndOfTrack = true
    }

    func clearStopAtEndOfTrack() {
        stopAtEndOfTrack = false
    }

    nonisolated deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
        }
    }
}

// MARK: - Proxies (CADisplayLink / AVAudioPlayerDelegate need NSObject)

private final class DisplayLinkProxy: NSObject {
    static let shared = DisplayLinkProxy()
    weak var owner: AudioPlayerManager?

    @objc func tick() {
        Task { @MainActor in
            owner?.tick()
        }
    }
}

private final class PlayerDelegateProxy: NSObject, AVAudioPlayerDelegate {
    static let shared = PlayerDelegateProxy()
    weak var owner: AudioPlayerManager?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            owner?.playerDidFinish()
        }
    }
}
