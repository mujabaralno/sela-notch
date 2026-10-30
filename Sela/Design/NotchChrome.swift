import SwiftUI

enum SelaPanel: Int, CaseIterable {
    case timer = 0
    case battery
    case music
    case calendar
    case shelf
}

struct SelaNavigation: View {
    @ObservedObject var selection: NotchPanelSelection
    @Namespace private var indicator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let tabs: [(SelaPanel, String, String)] = [
        (.timer, "Timer", "timer"),
        (.battery, "Baterai", "battery.100"),
        (.music, "Music", "music.note"),
        (.calendar, "Calendar", "calendar"),
        (.shelf, "Shelf", "tray"),
    ]
    var body: some View {
        HStack(spacing: 4) {
            Text("sela").font(.system(size: 13, weight: .semibold)).tracking(1).selaSecondary()
            Spacer()
            ForEach(tabs.indices, id: \.self) { index in
                let tab = tabs[index]
                Button { withAnimation(reduceMotion ? SelaTheme.fade : SelaTheme.spring) { selection.select(tab.0.rawValue) } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.2)
                        if selection.index == tab.0.rawValue { Text(tab.1) }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .frame(minWidth: 28, minHeight: 28).padding(.horizontal, 8)
                    .background {
                        if selection.index == tab.0.rawValue {
                            RoundedRectangle(cornerRadius: 10).fill(SelaTheme.raised)
                                .matchedGeometryEffect(id: "tab", in: indicator)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain).help(tab.1).accessibilityLabel(tab.1)
                    .accessibilityAddTraits(selection.index == tab.0.rawValue ? .isSelected : [])
            }
        }.foregroundStyle(SelaTheme.ivory)
    }
}

/// Presentation priority only; no feature model is changed by choosing an activity.
enum SelaLiveActivity {
    case alarm, timer, music, battery, shelf, idle
    @MainActor static func resolve(timer: TimerModel, battery: BatteryModel, music: MusicService, shelf: ShelfService? = nil) -> Self {
        // alarm > running/paused timer > playing music > battery event/low > idle
        if timer.phase == .finished { return .alarm }
        if timer.showsCompactTime { return .timer }
        if music.snapshot != nil { return .music }
        if battery.alert != nil || (battery.alertsEnabled && battery.condition == .onBattery && (battery.percentage ?? 100) <= BatteryAlertPolicy.lowBatteryThreshold) { return .battery }
        if let shelf, !shelf.items.isEmpty { return .shelf }
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
    @ObservedObject var shelf: ShelfService
    var leading: Bool
    var body: some View {
        Group {
            switch SelaLiveActivity.resolve(timer: timer, battery: battery, music: music, shelf: shelf) {
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
            case .shelf:
                if leading { Image(systemName: "tray.fill") }
                else { Text("\(shelf.items.count)").monospacedDigit() }
            case .idle: Color.clear.frame(width: 1, height: 1)
            }
        }.font(.system(size: 13, weight: .medium)).foregroundStyle(SelaTheme.ivory).preferredColorScheme(.dark)
    }
}
