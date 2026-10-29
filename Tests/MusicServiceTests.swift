import Foundation

@MainActor
final class FakeMusicProvider: MusicProvider {
    var onUpdate: ((MusicSnapshot?, Bool) -> Void)?
    var starts = 0
    var stops = 0
    var commands: [MusicCommand] = []
    func start() { starts += 1 }
    func stop() { stops += 1 }
    func send(_ command: MusicCommand, snapshot: MusicSnapshot) { commands.append(command); tokens.append(snapshot.sessionToken) }
    var tokens: [String] = []
}

@main
struct MusicServiceTests {
    @MainActor static func main() {
        let provider = FakeMusicProvider()
        let service = MusicService(provider: provider)
        service.start()
        service.start()
        precondition(provider.starts == 1)
        service.send(.toggle, expectedToken: service.snapshot?.sessionToken ?? "")
        precondition(provider.commands.isEmpty)
        provider.onUpdate?(MusicSnapshot(title: "Synthetic", playing: true, sessionToken: "session-a", capabilitiesKnown: true, enabledCommands: [2]), false)
        precondition(service.isPlaying)
        service.send(.next, expectedToken: service.snapshot?.sessionToken ?? "")
        precondition(provider.commands.isEmpty)
        service.send(.toggle, expectedToken: service.snapshot?.sessionToken ?? "")
        precondition(provider.commands.count == 1)
        precondition(service.isPlaying, "Commands must not optimistically change playback")
        provider.onUpdate?(MusicSnapshot(title: "Other source", playing: false, sessionToken: "session-b", capabilitiesKnown: true, enabledCommands: [0, 5]), false)
        precondition(!service.isPlaying)
        service.send(.previous, expectedToken: service.snapshot?.sessionToken ?? "")
        precondition(provider.commands.count == 2)
        service.send(.toggle, expectedToken: "session-a")
        precondition(provider.commands.count == 2, "Stale rendered controls must not control a new session")
        precondition(provider.tokens == ["session-a", "session-b"])
        service.send(.next, expectedToken: service.snapshot?.sessionToken ?? "")
        precondition(provider.commands.count == 2, "Previous and Next must be independent")
        let source = service.snapshot!
        precondition(source.commandID(.toggle) == 0 && source.supports(.toggle))
        provider.onUpdate?(MusicSnapshot(playing: true, sessionToken: "session-c", capabilitiesKnown: false, enabledCommands: [2, 4, 5]), false)
        service.send(.next, expectedToken: service.snapshot?.sessionToken ?? "")
        service.send(.toggle, expectedToken: service.snapshot?.sessionToken ?? "")
        precondition(provider.commands.count == 2, "Adapter unknown must fail closed")
        provider.onUpdate?(MusicSnapshot(playing: true, sessionToken: "session-d", capabilitiesKnown: true, enabledCommands: []), false)
        precondition(service.snapshot!.capabilitiesKnown && !service.snapshot!.supports(.previous))
        service.send(.previous, expectedToken: service.snapshot?.sessionToken ?? "")
        precondition(provider.commands.count == 2, "Known unsupported must fail closed")
        precondition(MusicSnapshot(playing: true, sessionToken: "s", capabilitiesKnown: true, enabledCommands: [1]).commandID(.toggle) == 1)
        precondition(!MusicSnapshot(playing: true, capabilitiesKnown: true, enabledCommands: [2]).supports(.toggle))
        provider.onUpdate?(nil, true)
        precondition(service.snapshot == nil && service.unavailable)
        service.send(.toggle, expectedToken: service.snapshot?.sessionToken ?? "")
        precondition(provider.commands.count == 2)
        provider.onUpdate?(nil, false)
        precondition(service.snapshot == nil && !service.unavailable)
        service.stop()
        precondition(provider.stops == 1 && provider.onUpdate == nil)
        print("Music service tests passed (synthetic provider)")
    }
}
