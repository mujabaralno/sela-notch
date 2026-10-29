import SwiftUI

struct CompactStatusLabel: View {
    @ObservedObject var timer: TimerModel
    @ObservedObject var battery: BatteryModel

    var body: some View {
        if let alert = battery.alert {
            HStack(spacing: 4) {
                Image(systemName: alert.symbolName)
                    .accessibilityHidden(true)

                Text(alert.compactMessage)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            .font(.caption)
            .monospacedDigit()
            .accessibilityLabel(alert.message)
        } else {
            Text(timer.showsCompactTime ? timer.timeText : "Sela")
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }
}

#Preview {
    CompactStatusLabel(timer: TimerModel(), battery: BatteryModel())
}
