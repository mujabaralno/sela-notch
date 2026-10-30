import SwiftUI

struct ContentView: View {
    @StateObject private var notch = NotchController()
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Sela").font(.system(size: 20, weight: .semibold))
                Spacer()
                Text("Di sela aktivitas Anda").font(.system(size: 11)).selaSecondary()
            }
            NotchExpandedContent(selection: notch.selection, timer: notch.timer, battery: notch.battery, music: notch.music, shelf: notch.shelf, calendar: notch.calendar)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            HStack(spacing: 8) {
                Button("Buka notch") { notch.expand() }.buttonStyle(SelaButtonStyle(prominent: true)).keyboardShortcut(.defaultAction)
                Button("Ringkas") { notch.compact() }.buttonStyle(SelaButtonStyle())
                SelaIconButton(symbol: "eye.slash", label: "Sembunyikan notch") { notch.hide() }
                Spacer()
            }
        }.padding(24).frame(width: 456).selaSurface()
    }
}
