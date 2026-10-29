import SwiftUI

struct ContentView: View {
    @StateObject private var notch = NotchController()

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("Sela")
                    .font(.largeTitle.weight(.semibold))

                Text("Contoh integrasi DynamicNotchKit")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

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
        .padding(32)
        .frame(width: 460, height: 300)
    }
}

#Preview {
    ContentView()
}
