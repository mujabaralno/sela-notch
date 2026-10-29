import SwiftUI

struct SelaNavigation: View {
    @ObservedObject var selection: NotchPanelSelection
    @Namespace private var indicator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let tabs = [("Timer", "timer"), ("Baterai", "battery.100"), ("Music", "music.note")]
    var body: some View {
        HStack(spacing: 4) {
            Text("sela").font(.system(size: 13, weight: .semibold)).tracking(1).selaSecondary()
            Spacer()
            ForEach(tabs.indices, id: \.self) { index in
                Button { withAnimation(reduceMotion ? SelaTheme.fade : SelaTheme.spring) { selection.select(index) } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tabs[index].1)
                        if selection.index == index { Text(tabs[index].0) }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .frame(minWidth: 28, minHeight: 28).padding(.horizontal, 8)
                    .background {
                        if selection.index == index {
                            RoundedRectangle(cornerRadius: 10).fill(SelaTheme.raised)
                                .matchedGeometryEffect(id: "tab", in: indicator)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain).help(tabs[index].0).accessibilityLabel(tabs[index].0)
                    .accessibilityAddTraits(selection.index == index ? .isSelected : [])
            }
        }.foregroundStyle(SelaTheme.ivory)
    }
}

/// Presentation priority only; no feature model is changed by choosing an activity.
enum SelaLiveActivity {
    case alarm, timer, music, battery, idle
    @MainActor static func resolve(timer: TimerModel, battery: BatteryModel, music: MusicService) -> Self {
        // alarm > running/paused timer > playing music > battery event/low > idle
        if timer.phase == .finished { return .alarm }
        if timer.showsCompactTime { return .timer }
        if music.snapshot != nil { return .music }
        if battery.alert != nil || (battery.alertsEnabled && battery.condition == .onBattery && (battery.percentage ?? 100) <= BatteryAlertPolicy.lowBatteryThreshold) { return .battery }
        return .idle
    }
}

struct SelaEqualizer: View {
    var playing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.18, paused: !playing || reduceMotion)) { context in
            HStack(spacing: 3) {
                ForEach(0..<4) { index in
                    Capsule().frame(width: 3, height: playing && !reduceMotion ? 5 + 11 * abs(sin(context.date.timeIntervalSinceReferenceDate * 3 + Double(index))) : 5)
                }
            }.frame(width: 24, height: 20)
        }.foregroundStyle(SelaTheme.ivory).opacity(playing ? 1 : 0.45).accessibilityLabel(playing ? "Media diputar" : "Media dijeda")
    }
}

struct SelaCompactWing: View {
    @ObservedObject var timer: TimerModel
    @ObservedObject var battery: BatteryModel
    @ObservedObject var music: MusicService
    var leading: Bool
    var body: some View {
        Group {
            switch SelaLiveActivity.resolve(timer: timer, battery: battery, music: music) {
            case .alarm:
                if leading { SelaAlarmSymbol() }
                else { Text("Selesai").foregroundStyle(SelaTheme.amber) }
            case .timer:
                if leading {
                    SelaRing(progress: timer.remaining / timer.session.duration, tint: timer.session == .focus ? SelaTheme.amber : SelaTheme.rest, lineWidth: 2).frame(width: 16, height: 16)
                } else { Text(timer.timeText).monospacedDigit() }
            case .music:
                if leading { MusicArtwork(image: music.snapshot?.artwork, size: 24) }
                else { SelaEqualizer(playing: music.isPlaying) }
            case .battery:
                if leading { Image(systemName: battery.alert?.symbolName ?? "battery.25").foregroundStyle((battery.percentage ?? 100) <= BatteryAlertPolicy.lowBatteryThreshold ? SelaTheme.amber : SelaTheme.green) }
                else { Text(battery.percentage.map { "\($0)%" } ?? "—").monospacedDigit() }
            case .idle: Color.clear.frame(width: 1, height: 1)
            }
        }.font(.system(size: 13, weight: .medium)).foregroundStyle(SelaTheme.ivory).preferredColorScheme(.dark)
    }
}
