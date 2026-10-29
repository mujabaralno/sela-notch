import SwiftUI

/// Synthesized presentation only: never creates a timer, battery reader or media provider.
struct SelaStatePreview: View {
    enum State { case idle, compact, expanded }
    let state: State
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if state == .compact { SelaRing(progress: 0.7, tint: SelaTheme.amber, lineWidth: 2).frame(width: 16, height: 16) }
                Color.black.frame(width: 160, height: 28)
                if state == .compact { Text("18:42").font(.system(size: 13)).monospacedDigit() }
            }
            if state == .expanded {
                VStack(spacing: 12) {
                    HStack {
                        Text("sela").selaSecondary()
                        Spacer()
                        Label("Timer", systemImage: "timer")
                        Image(systemName: "battery.100").padding(.horizontal, 12)
                        Image(systemName: "music.note")
                    }.font(.system(size: 11, weight: .medium)).frame(height: 28)
                    TimerFace(time: "18:42", phase: "Berjalan", session: .focus, progress: 0.75, running: true,
                              select: { _ in }, start: {}, pause: {}, reset: {}) { EmptyView() }
                }.padding(16).frame(width: SelaTheme.width)
            }
        }.padding(.horizontal, 16).padding(.bottom, 8).selaSurface()
            .clipShape(SelaNotchShape())
            .padding(.horizontal, 32).padding(.bottom, 32)
            .background(Color(red: 0.26, green: 0.28, blue: 0.26))
    }
}
#Preview("Idle") { SelaStatePreview(state: .idle) }
#Preview("Compact") { SelaStatePreview(state: .compact) }
#Preview("Expanded") { SelaStatePreview(state: .expanded) }
#Preview("Music · Paused / long title") {
    VStack {
        MusicFace(media: MusicSnapshot(title: "A long title that moves quietly within the available space", artist: "Studio session", source: "Music", playing: false,
                                      sessionToken: "preview", capabilitiesKnown: true, enabledCommands: [0])) { _, _ in }
    }.padding(16).frame(width: 408).selaSurface()
}
#Preview("Battery · Unavailable") {
    BatteryFace(percentage: nil, condition: "Informasi baterai tidak tersedia pada perangkat ini", alertsEnabled: .constant(false), refresh: {})
        .padding(16).frame(width: 408).selaSurface()
}
#Preview("Timer · Rest") {
    TimerFace(time: "05:00", phase: "Siap", session: .rest, progress: 1,
              select: { _ in }, start: {}, pause: {}, reset: {}) { EmptyView() }
        .padding(16).frame(width: 408).selaSurface()
}
