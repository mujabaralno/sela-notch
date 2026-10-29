import AppKit
import Combine

struct MusicSnapshot {
    var title: String?
    var artist: String?
    var source: String?
    var playing: Bool
    var artwork: NSImage?
    // Unknown capabilities stay disabled rather than promising unsupported skips.
    var canSkip = false
}

enum MusicCommand { case toggle, previous, next }

@MainActor
protocol MusicProvider: AnyObject {
    var onUpdate: ((MusicSnapshot?, Bool) -> Void)? { get set }
    func start()
    func stop()
    func send(_ command: MusicCommand)
}

@MainActor
final class MusicService: ObservableObject {
    @Published private(set) var snapshot: MusicSnapshot?
    @Published private(set) var unavailable = false
    private let provider: MusicProvider
    private var started = false

    init(provider: MusicProvider) { self.provider = provider }
    var isPlaying: Bool { snapshot?.playing == true }
    func start() {
        guard !started else { return }
        started = true
        provider.onUpdate = { [weak self] snapshot, failed in
            self?.snapshot = failed ? nil : snapshot
            self?.unavailable = failed
        }
        provider.start()
    }
    func stop() {
        started = false
        provider.onUpdate = nil
        provider.stop()
        snapshot = nil
    }
    func send(_ command: MusicCommand) {
        guard !unavailable, let snapshot else { return }
        if command != .toggle && !snapshot.canSkip { return }
        provider.send(command)
    }
}
