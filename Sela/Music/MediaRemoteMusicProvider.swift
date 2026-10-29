import AppKit
import MediaRemoteAdapter

/// Uses the bundled adapter through system Perl. No metadata is logged or persisted.
@MainActor
final class MediaRemoteMusicProvider: MusicProvider {
    var onUpdate: ((MusicSnapshot?, Bool) -> Void)?
    private var process: Process?
    private var input: Pipe?
    private var reader: Task<Void, Never>?

    func start() {
        guard process == nil else { return }
        let framework = Bundle(for: MediaController.self)
        let roots = [Bundle.main.resourceURL, framework.resourceURL, Bundle.main.bundleURL.deletingLastPathComponent()].compactMap { $0 }
        let resource = roots.compactMap {
            Bundle(url: $0.appendingPathComponent("MediaRemoteAdapter_MediaRemoteAdapter.bundle"))
        }.first
        guard let script = resource?.url(forResource: "run", withExtension: "pl"),
              let library = framework.executableURL else {
            onUpdate?(nil, true)
            return
        }
        signal(SIGPIPE, SIG_IGN)
        let child = Process()
        let output = Pipe()
        let input = Pipe()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        child.arguments = [script.path, library.path, "loop"]
        child.standardOutput = output
        child.standardInput = input
        child.standardError = FileHandle.nullDevice
        child.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard self?.process === child else { return }
                self?.process = nil
                self?.input = nil
                self?.onUpdate?(nil, true)
            }
        }
        do {
            try child.run()
            process = child
            self.input = input
            reader = Task { [weak self] in
                do {
                    for try await line in output.fileHandleForReading.bytes.lines {
                        guard !Task.isCancelled else { return }
                        self?.receive(line)
                    }
                } catch {
                    guard !Task.isCancelled, self?.process === child else { return }
                    self?.onUpdate?(nil, true)
                }
            }
        } catch { onUpdate?(nil, true) }
    }

    private func receive(_ line: String) {
        if line == "NIL" { onUpdate?(nil, false); return }
        guard let data = line.data(using: .utf8),
              let track = try? JSONDecoder().decode(TrackInfo.self, from: data) else {
            onUpdate?(nil, true)
            return
        }
        let p = track.payload
        guard p.bundleIdentifier != nil || p.title != nil else {
            onUpdate?(nil, false)
            return
        }
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let payload = object?["payload"] as? [String: Any]
        let token = payload?["sessionToken"] as? String ?? ""
        let known = payload?["capabilitiesKnown"] as? Bool ?? false
        let enabled = Set(payload?["enabledCommands"] as? [Int] ?? [])
        onUpdate?(MusicSnapshot(title: p.title, artist: p.artist,
                                source: p.applicationName ?? p.bundleIdentifier,
                                playing: p.isPlaying == true, artwork: p.artwork, sessionToken: token, capabilitiesKnown: known, enabledCommands: enabled), false)
    }

    func send(_ command: MusicCommand, snapshot: MusicSnapshot) {
        guard process?.isRunning == true, let input, snapshot.supports(command),
              UUID(uuidString: snapshot.sessionToken) != nil else { return }
        let line = "guarded \(snapshot.sessionToken) \(snapshot.commandID(command))\n"
        do { try input.fileHandleForWriting.write(contentsOf: Data(line.utf8)) }
        catch { onUpdate?(nil, true) }
    }

    func stop() {
        reader?.cancel()
        reader = nil
        let child = process
        process = nil
        child?.terminationHandler = nil
        child?.terminate()
        input = nil
    }
}
