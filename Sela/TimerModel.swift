import AppKit
import Foundation

@MainActor
final class TimerModel: ObservableObject {
    enum Session: String, CaseIterable, Identifiable {
        case focus
        case rest

        var id: String { rawValue }

        var title: String {
            switch self {
            case .focus: "Fokus"
            case .rest: "Istirahat"
            }
        }

        var duration: TimeInterval {
            switch self {
            case .focus: 25 * 60
            case .rest: 5 * 60
            }
        }
    }

    enum Phase {
        case idle
        case running
        case paused
        case finished
    }

    @Published private(set) var session: Session = .focus
    @Published private(set) var remaining: TimeInterval = Session.focus.duration
    @Published private(set) var phase: Phase = .idle

    private var ticker: Timer?
    private var deadline: Date?
    private var didRing = false

    var timeText: String {
        let seconds = max(0, Int(remaining.rounded(.up)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    var phaseText: String {
        switch phase {
        case .idle: "Siap"
        case .running: "Berjalan"
        case .paused: "Dijeda"
        case .finished: "Selesai"
        }
    }

    var startTitle: String {
        switch phase {
        case .paused: "Lanjutkan"
        case .finished: "Mulai Lagi"
        case .idle, .running: "Mulai"
        }
    }

    var showsCompactTime: Bool {
        phase != .idle
    }

    func select(_ session: Session) {
        guard session != self.session else { return }
        stopTicker()
        deadline = nil
        self.session = session
        remaining = session.duration
        phase = .idle
        didRing = false
    }

    func start() {
        guard phase != .running else { return }

        if phase == .finished || remaining <= 0 {
            remaining = session.duration
            didRing = false
        }

        deadline = Date().addingTimeInterval(remaining)
        phase = .running
        startTicker()
    }

    func pause() {
        guard phase == .running else { return }

        if let deadline {
            remaining = max(0, deadline.timeIntervalSinceNow)
        }

        stopTicker()
        deadline = nil
        if remaining <= 0 {
            finish()
        } else {
            phase = .paused
        }
    }

    func reset() {
        stopTicker()
        deadline = nil
        remaining = session.duration
        phase = .idle
        didRing = false
    }

    private func startTicker() {
        stopTicker()

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard phase == .running, let deadline else { return }

        let left = deadline.timeIntervalSinceNow
        if left <= 0 {
            remaining = 0
            finish()
        } else {
            remaining = left
        }
    }

    private func finish() {
        stopTicker()
        deadline = nil
        remaining = 0
        phase = .finished

        guard !didRing else { return }
        didRing = true

        if let sound = NSSound(named: "Glass") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}
