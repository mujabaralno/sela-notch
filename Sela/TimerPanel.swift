import SwiftUI

struct TimerPanel: View {
    @ObservedObject var timer: TimerModel

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                PetView(timer: timer)

                VStack(alignment: .leading, spacing: 0) {
                    Text(timer.timeText)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()

                    Text("\(timer.session.title) · \(timer.phaseText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                sessionPicker
            }

            HStack(spacing: 8) {
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
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 272)
    }

    private var sessionPicker: some View {
        VStack(spacing: 2) {
            ForEach(TimerModel.Session.allCases) { session in
                Button {
                    timer.select(session)
                } label: {
                    Text(session.title)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(timer.session == session ? .primary : .secondary)
                        .frame(width: 62)
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .background {
                            if timer.session == session {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.primary.opacity(0.16))
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(timer.session == session ? .isSelected : [])
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.primary.opacity(0.07))
        )
    }
}

#Preview {
    TimerPanel(timer: TimerModel())
}
