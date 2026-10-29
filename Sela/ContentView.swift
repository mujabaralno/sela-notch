import SwiftUI

struct ContentView: View {
    @StateObject private var notch = NotchController()

    var body: some View {
        VStack(spacing: 18) {
            TimerPanel(timer: notch.timer)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))

            HStack(spacing: 12) {
                Button("Tampilkan Notch") {
                    notch.expand()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)

                Button("Ringkas") {
                    notch.compact()
                }
                .buttonStyle(.bordered)

                Button("Sembunyikan") {
                    notch.hide()
                }
                .buttonStyle(.bordered)
            }

            Text("Status notch: \(notch.status.rawValue)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(24)
        .frame(width: 380, height: 360)
    }
}

#Preview {
    ContentView()
}
