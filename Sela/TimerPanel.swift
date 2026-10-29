import SwiftUI

struct TimerPanel: View {
    @ObservedObject var timer: TimerModel

    var body: some View {
        VStack(spacing: 14) {
            Picker(
                "Sesi",
                selection: Binding(get: { timer.session }, set: { timer.select($0) })
            ) {
                ForEach(TimerModel.Session.allCases) { session in
                    Text(session.title).tag(session)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VStack(spacing: 2) {
                Text(timer.timeText)
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                Text("\(timer.session.title) · \(timer.phaseText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button(timer.startTitle) {
                    timer.start()
                }
                .buttonStyle(.borderedProminent)
                .disabled(timer.phase == .running)

                Button("Jeda") {
                    timer.pause()
                }
                .buttonStyle(.bordered)
                .disabled(timer.phase != .running)

                Button("Reset") {
                    timer.reset()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}

#Preview {
    TimerPanel(timer: TimerModel())
}
