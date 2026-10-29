import SwiftUI

struct MusicArtwork: View {
    let image: NSImage?
    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().scaledToFill() }
            else { Image(systemName: "music.note").resizable().scaledToFit().padding(8) }
        }
        .frame(width: 36, height: 36)
        .clipped()
        .cornerRadius(6)
        .accessibilityLabel("Sampul media")
    }
}

struct MusicPanel: View {
    @ObservedObject var music: MusicService
    var body: some View {
        VStack(spacing: 12) {
            if let media = music.snapshot {
                HStack {
                    MusicArtwork(image: media.artwork)
                    VStack(alignment: .leading) {
                        Text(media.title ?? "Media tanpa judul").font(.headline).lineLimit(2)
                        Text(media.artist ?? "Artis / kanal tidak tersedia").lineLimit(1)
                        Text(media.source ?? "Now Playing macOS").font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 24) {
                    Button { music.send(.previous, expectedToken: media.sessionToken) } label: { Image(systemName: "backward.end.fill") }
                        .disabled(!media.supports(.previous)).accessibilityLabel("Previous")
                    Button { music.send(.toggle, expectedToken: media.sessionToken) } label: { Image(systemName: media.playing ? "pause.fill" : "play.fill") }
                        .disabled(!media.supports(.toggle))
                        .accessibilityLabel(media.playing ? "Pause" : "Play")
                    Button { music.send(.next, expectedToken: media.sessionToken) } label: { Image(systemName: "forward.end.fill") }
                        .disabled(!media.supports(.next)).accessibilityLabel("Next")
                }
                if !media.capabilitiesKnown {
                    Text("Kemampuan kontrol tidak tersedia melalui adapter pada macOS ini.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if !media.supports(.previous) || !media.supports(.next) {
                    Text("Sumber aktif tidak mengaktifkan " +
                         ([(!media.supports(.previous) ? "Previous" : nil), (!media.supports(.next) ? "Next" : nil)].compactMap { $0 }.joined(separator: " / ")) + ".").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "music.note")
                Text(music.unavailable ? "Koneksi Now Playing tidak tersedia" : "Tidak ada sesi Now Playing")
                Text("Putar media di aplikasi yang menerbitkan sesi Now Playing macOS.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}
