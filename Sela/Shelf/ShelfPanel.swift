import SwiftUI

struct ShelfPanel: View {
    @ObservedObject var shelf: ShelfService
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(shelf.items.count) / \(ShelfService.capacity) file").font(.system(size: 13, weight: .medium)).monospacedDigit()
                Spacer()
                Button("Bersihkan") { shelf.clear() }.buttonStyle(SelaButtonStyle())
                    .disabled(shelf.items.isEmpty || shelf.isBusy).help("Hapus semua titipan; file asli tetap ada")
            }
            if shelf.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down").font(.system(size: 24, weight: .light)).accessibilityHidden(true)
                    Text(shelf.targeted ? "Lepaskan file di sini" : "Titipkan file sebentar")
                        .font(.system(size: 15, weight: .medium))
                    Text("Tarik file dari Finder ke notch. File asli tetap di tempatnya.")
                        .font(.system(size: 11)).selaSecondary().multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).frame(height: 116)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(shelf.items) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                ShelfDragItem(item: item, shelf: shelf).frame(height: 72)
                                Button { shelf.remove(item.id) } label: { Label("Hapus titipan", systemImage: "xmark") }
                                    .font(.system(size: 11)).buttonStyle(SelaButtonStyle()).disabled(shelf.isBusy)
                                    .accessibilityLabel("Hapus titipan \(item.name)")
                            }.padding(8).background(SelaTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }.frame(height: 228)
            }
            if let message = shelf.message {
                Text(message).font(.system(size: 11)).selaSecondary().fixedSize(horizontal: false, vertical: true)
            }
        }.foregroundStyle(SelaTheme.ivory)
            .onAppear { shelf.refreshAvailability() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in shelf.refreshAvailability() }
    }
}
#Preview("Shelf · Empty") { ShelfPanel(shelf: ShelfService(thumbnails: false)).padding(16).frame(width: 408).selaSurface() }
