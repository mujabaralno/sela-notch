import AppKit
import Combine

struct MusicSnapshot {
    var title: String?
    var artist: String?
    var source: String?
    var playing: Bool
    var artwork: NSImage?
    var sessionToken: String = ""
    var capabilitiesKnown = false
    var enabledCommands: Set<Int> = []

    func commandID(_ command: MusicCommand) -> Int {
        switch command {
        case .previous: return 5
        case .next: return 4
        case .toggle:
            if enabledCommands.contains(2) { return 2 }
            return playing ? 1 : 0
        }
    }
    func supports(_ command: MusicCommand) -> Bool {
        capabilitiesKnown && !sessionToken.isEmpty && enabledCommands.contains(commandID(command))
    }
}

enum MusicCommand { case toggle, previous, next }

@MainActor
protocol MusicProvider: AnyObject {
    var onUpdate: ((MusicSnapshot?, Bool) -> Void)? { get set }
    func start()
    func stop()
    func send(_ command: MusicCommand, snapshot: MusicSnapshot)
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
    func send(_ command: MusicCommand, expectedToken: String) {
        guard !unavailable, let snapshot, snapshot.sessionToken == expectedToken else { return }
        guard snapshot.supports(command) else { return }
        provider.send(command, snapshot: snapshot)
    }
}
