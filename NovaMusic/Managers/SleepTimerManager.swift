import Foundation

@MainActor
@Observable
final class SleepTimerManager {
    private(set) var isActive = false
    private(set) var endsAt: Date?
    private(set) var remaining: TimeInterval = 0
    private(set) var option: SleepTimerOption?

    private var timer: Timer?
    private weak var player: AudioPlayerManager?

    func bind(player: AudioPlayerManager) {
        self.player = player
    }

    func schedule(_ option: SleepTimerOption) {
        cancel()
        self.option = option
        switch option {
        case .minutes(let minutes):
            let ends = Date().addingTimeInterval(TimeInterval(minutes * 60))
            endsAt = ends
            isActive = true
            remaining = ends.timeIntervalSinceNow
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.tick()
                }
            }
        case .endOfTrack:
            isActive = true
            endsAt = nil
            remaining = 0
            player?.armStopAtEndOfTrack()
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        isActive = false
        endsAt = nil
        remaining = 0
        option = nil
        player?.clearStopAtEndOfTrack()
    }

    private func tick() {
        guard let endsAt else { return }
        remaining = max(0, endsAt.timeIntervalSinceNow)
        if remaining <= 0 {
            player?.pause()
            cancel()
        }
    }

    var remainingFormatted: String {
        DurationFormatter.string(from: remaining)
    }
}
