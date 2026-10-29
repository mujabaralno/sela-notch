import SwiftUI

struct ContentView: View {
    @StateObject private var notch = NotchController()

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                panelButton("Timer", panel: 0)
                panelButton("Baterai", panel: 1)
            }
            BatteryAlertBanner(battery: notch.battery)
            Group {
                if notch.selectedPanel == 0 { TimerPanel(timer: notch.timer) }
                else { BatteryPanel(battery: notch.battery) }
            }
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
        .padding(20)
        .frame(width: 340, height: 430)
    }

    @ViewBuilder
    private func panelButton(_ title: String, panel: Int) -> some View {
        if notch.selectedPanel == panel {
            Button(title) { notch.selectedPanel = panel }
                .buttonStyle(.borderedProminent)
        } else {
            Button(title) { notch.selectedPanel = panel }
                .buttonStyle(.bordered)
        }
    }
}

#Preview {
    ContentView()
}
