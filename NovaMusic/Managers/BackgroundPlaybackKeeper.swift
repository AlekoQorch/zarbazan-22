import Foundation
import AVFoundation
import UIKit
import WebKit

/// Keeps the audio session active and aggressively resumes playback when iOS
/// pauses media after the device is locked or the app is backgrounded.
@MainActor
@Observable
final class BackgroundPlaybackKeeper {
    static let shared = BackgroundPlaybackKeeper()

    private(set) var wantPlaying = false
    weak var youtubeWebView: WKWebView?
    private var resumeTimer: Timer?
    private var silentPlayer: AVAudioPlayer?
    private var observers: [NSObjectProtocol] = []

    private init() {
        activateSession()
        observeLifecycle()
        prepareSilentPlayer()
    }

    func setWantPlaying(_ value: Bool) {
        wantPlaying = value
        if value {
            activateSession()
            startSilentKeepAlive()
            startResumeLoop()
            forceResume()
        } else {
            stopResumeLoop()
            stopSilentKeepAlive()
        }
    }

    func bindYouTubeWebView(_ webView: WKWebView?) {
        youtubeWebView = webView
    }

    func activateSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetoothA2DP]
            )
            try session.setActive(true, options: [])
        } catch {
            print("NovaMusic: audio session — \(error)")
        }
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    private func prepareSilentPlayer() {
        // Minimal valid silent WAV bytes
        let base64 = "UklGRigAAABXQVZFZm10IBIAAAABAAEARKwAAIhYAQACABAAAABkYXRhAgAAAAEA"
        guard let data = Data(base64Encoded: base64) else { return }
        do {
            let player = try AVAudioPlayer(data: data)
            player.numberOfLoops = -1
            player.volume = 0.01
            player.prepareToPlay()
            silentPlayer = player
        } catch {
            silentPlayer = nil
        }
    }

    private func startSilentKeepAlive() {
        activateSession()
        silentPlayer?.play()
    }

    private func stopSilentKeepAlive() {
        silentPlayer?.stop()
    }

    private func startResumeLoop() {
        stopResumeLoop()
        resumeTimer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.forceResume()
            }
        }
    }

    private func stopResumeLoop() {
        resumeTimer?.invalidate()
        resumeTimer = nil
    }

    func forceResume() {
        guard wantPlaying else { return }
        activateSession()
        startSilentKeepAlive()
        NotificationCenter.default.post(name: .novaForceResumePlayback, object: nil)
    }

    private func observeLifecycle() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.wantPlaying else { return }
                self.activateSession()
                self.startSilentKeepAlive()
                self.forceResume()
                // Burst resumes after lock
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.forceResume() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.forceResume() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { self.forceResume() }
            }
        })
        observers.append(center.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.forceResume()
            }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                guard let self, self.wantPlaying else { return }
                let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                    .flatMap(AVAudioSession.InterruptionType.init)
                if type == .ended {
                    self.forceResume()
                    NotificationCenter.default.post(name: .novaForceResumePlayback, object: nil)
                }
            }
        })
    }
}

extension Notification.Name {
    static let novaForceResumePlayback = Notification.Name("nova.forceResumePlayback")
}
