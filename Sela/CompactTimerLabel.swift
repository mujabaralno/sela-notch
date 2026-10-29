import SwiftUI

struct CompactTimerLabel: View {
    @ObservedObject var timer: TimerModel

    var body: some View {
        Text(timer.showsCompactTime ? timer.timeText : "Sela")
            .font(.caption)
            .fontWeight(.semibold)
            .monospacedDigit()
    }
}
