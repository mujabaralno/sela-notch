import SwiftUI

struct MusicArtwork: View {
    let image: NSImage?
    var size: CGFloat = 36
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.16).fill(SelaTheme.raised)
            if let image { Image(nsImage: image).resizable().scaledToFill() }
            else { Image(systemName: "music.note").font(.system(size: max(11, size * 0.35), weight: .medium)).selaSecondary() }
        }.frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.16))
            .accessibilityLabel(image == nil ? "Sampul tidak tersedia" : "Sampul media")
    }
}
struct MusicPanel: View {
    @ObservedObject var music: MusicService
    var body: some View {
        MusicFace(media: music.snapshot, unavailable: music.unavailable) { command, token in
            music.send(command, expectedToken: token)
        }
    }
}
struct MusicFace: View {
    let media: MusicSnapshot?
    var unavailable = false
    var send: (MusicCommand, String) -> Void
    var body: some View {
        Group {
            if let media {
                HStack(spacing: 16) {
                    MusicArtwork(image: media.artwork, size: 80).modifier(SelaArrival(delay: 0.04))
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            SelaMarquee(text: media.title ?? "Media tanpa judul")
                            Text(media.artist ?? "Artis tidak tersedia").font(.system(size: 13)).selaSecondary().lineLimit(1)
                        }
                        HStack(spacing: 8) {
                            SelaIconButton(symbol: "backward.end.fill", label: "Previous") { send(.previous, media.sessionToken) }
                                .disabled(!media.supports(.previous))
                            SelaIconButton(symbol: media.playing ? "pause.fill" : "play.fill", label: media.playing ? "Pause" : "Play", prominent: true) { send(.toggle, media.sessionToken) }
                                .disabled(!media.supports(.toggle))
                            SelaIconButton(symbol: "forward.end.fill", label: "Next") { send(.next, media.sessionToken) }
                                .disabled(!media.supports(.next))
                            Spacer(minLength: 0)
                        }
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "app.connected.to.app.below.fill").accessibilityHidden(true)
                    Text(media.source ?? "Now Playing macOS").lineLimit(1)
                    Spacer(minLength: 4)
                    if !media.capabilitiesKnown {
                        Text("Kontrol tidak tersedia").help("Kemampuan kontrol tidak tersedia melalui adapter pada macOS ini.")
                    } else if !media.supports(.previous) || !media.supports(.next) {
                        Text("Kontrol terbatas").help("Sumber tidak mengaktifkan semua kontrol Previous / Next.")
                    } else { Text(media.playing ? "Sedang diputar" : "Dijeda") }
                }.font(.system(size: 11)).selaSecondary()
            } else {
                HStack(spacing: 16) {
                    MusicArtwork(image: nil, size: 80)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(unavailable ? "Koneksi tidak tersedia" : "Tidak ada yang diputar").font(.system(size: 15, weight: .medium))
                        Text("Putar media di aplikasi yang mendukung Now Playing macOS.")
                            .font(.system(size: 13)).selaSecondary().fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }.foregroundStyle(SelaTheme.ivory)
    }
}
#Preview("Music · Playing") {
    VStack(spacing: 12) {
        MusicFace(media: MusicSnapshot(title: "A quiet afternoon", artist: "Studio session", source: "Music", playing: true,
                                       sessionToken: "preview", capabilitiesKnown: true, enabledCommands: [2, 4, 5])) { _, _ in }
    }.padding(16).frame(width: 408).selaSurface()
}
#Preview("Music · Empty") {
    MusicFace(media: nil) { _, _ in }.padding(16).frame(width: 408).selaSurface()
}
