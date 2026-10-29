import Foundation

@MainActor
final class FakeMusicProvider: MusicProvider {
    var onUpdate: ((MusicSnapshot?, Bool) -> Void)?
    var starts = 0
    var stops = 0
    var commands: [MusicCommand] = []
    func start() { starts += 1 }
    func stop() { stops += 1 }
    func send(_ command: MusicCommand) { commands.append(command) }
}

@main
struct MusicServiceTests {
    @MainActor static func main() {
        let provider = FakeMusicProvider()
        let service = MusicService(provider: provider)
        service.start()
        service.start()
        precondition(provider.starts == 1)
        service.send(.toggle)
        precondition(provider.commands.isEmpty)
        provider.onUpdate?(MusicSnapshot(title: "Synthetic", playing: true), false)
        precondition(service.isPlaying)
        service.send(.next)
        precondition(provider.commands.isEmpty)
        service.send(.toggle)
        precondition(provider.commands.count == 1)
        precondition(service.isPlaying, "Commands must not optimistically change playback")
        provider.onUpdate?(MusicSnapshot(title: "Other source", playing: false, canSkip: true), false)
        precondition(!service.isPlaying)
        service.send(.previous)
        precondition(provider.commands.count == 2)
        provider.onUpdate?(nil, true)
        precondition(service.snapshot == nil && service.unavailable)
        service.send(.toggle)
        precondition(provider.commands.count == 2)
        provider.onUpdate?(nil, false)
        precondition(service.snapshot == nil && !service.unavailable)
        service.stop()
        precondition(provider.stops == 1 && provider.onUpdate == nil)
        print("Music service tests passed (synthetic provider)")
    }
}
