import SwiftUI

struct TimerPanel: View {
    @ObservedObject var timer: TimerModel
    var body: some View {
        TimerFace(time: timer.timeText, phase: timer.phaseText, session: timer.session,
                  progress: timer.remaining / timer.session.duration,
                  running: timer.phase == .running, finished: timer.phase == .finished,
                  select: timer.select, start: timer.start, pause: timer.pause, reset: timer.reset) {
            PetView(timer: timer, height: 24)
        }
    }
}

struct TimerFace<Companion: View>: View {
    let time: String
    let phase: String
    let session: TimerModel.Session
    let progress: Double
    var running = false
    var finished = false
    var select: (TimerModel.Session) -> Void
    var start: () -> Void
    var pause: () -> Void
    var reset: () -> Void
    @ViewBuilder var companion: () -> Companion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var tint: Color { session == .focus ? SelaTheme.amber : SelaTheme.rest }
    var body: some View {
        HStack(spacing: 24) {
            ZStack {
                SelaRing(progress: progress, tint: tint)
                VStack(spacing: 4) {
                    Text(time).font(.system(size: 26, weight: .medium)).monospacedDigit().tracking(-1)
                    Text(finished ? "Sesi selesai" : phase).font(.system(size: 11)).selaSecondary()
                }
            }.frame(width: 108, height: 108).padding(4)
                .accessibilityElement(children: .combine)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 4) {
                    sessionButton(.focus, title: "Fokus 25")
                    sessionButton(.rest, title: "Istirahat 5")
                }
                HStack(spacing: 8) {
                    if finished {
                        Button(session == .focus ? "Mulai istirahat" : "Mulai fokus") {
                            select(session == .focus ? .rest : .focus); start()
                        }.buttonStyle(SelaButtonStyle(prominent: true))
                    } else {
                        Button(action: running ? pause : start) {
                            Label(running ? "Jeda" : "Mulai", systemImage: running ? "pause.fill" : "play.fill")
                        }.buttonStyle(SelaButtonStyle(prominent: true))
                    }
                    SelaIconButton(symbol: "arrow.counterclockwise", label: "Reset timer", action: reset)
                }
                HStack(spacing: 8) {
                    // Session markers express current mode, not an invented completion count.
                    Circle().fill(session == .focus ? tint : SelaTheme.raised).frame(width: 4, height: 4)
                    Circle().fill(session == .rest ? tint : SelaTheme.raised).frame(width: 4, height: 4)
                    Text(session.title).font(.system(size: 11)).selaSecondary()
                    Spacer(minLength: 0)
                    companion()
                }
            }
        }.frame(height: 116).foregroundStyle(SelaTheme.ivory)
    }
    private func sessionButton(_ value: TimerModel.Session, title: String) -> some View {
        Button { select(value) } label: {
            Text(title).font(.system(size: 11, weight: .medium)).frame(minHeight: 28).padding(.horizontal, 8)
                .foregroundStyle(session == value ? SelaTheme.ivory : SelaTheme.ivory.opacity(0.62))
                .background(session == value ? SelaTheme.raised : .clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).accessibilityAddTraits(session == value ? .isSelected : [])
    }
}

#Preview("Timer · Fokus") {
    TimerFace(time: "18:42", phase: "Berjalan", session: .focus, progress: 0.75, running: true,
              select: { _ in }, start: {}, pause: {}, reset: {}) { EmptyView() }
        .padding(16).frame(width: 408).selaSurface()
}
#Preview("Timer · Alarm") {
    TimerFace(time: "00:00", phase: "Selesai", session: .focus, progress: 0, finished: true,
              select: { _ in }, start: {}, pause: {}, reset: {}) { EmptyView() }
        .padding(16).frame(width: 408).selaSurface()
}
