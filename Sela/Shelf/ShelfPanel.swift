import SwiftUI

/// Compact horizontal rows; only long shelves get a scrolling viewport.
enum ShelfLayout {
    static let cardHeight: CGFloat = 56
    static let gap: CGFloat = 8
    static func gridHeight(itemCount: Int) -> CGFloat {
        let rows = min(3, max(1, itemCount))
        return CGFloat(rows) * cardHeight + CGFloat(rows - 1) * gap
    }
    static func panelHeight(itemCount: Int, hasMessage: Bool) -> CGFloat {
        (itemCount == 0 ? 240 : 120 + gridHeight(itemCount: itemCount)) + (hasMessage ? 40 : 0)
    }
}

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
                if shelf.items.count <= 3 {
                    rows
                } else {
                    ScrollView { rows }.frame(height: ShelfLayout.gridHeight(itemCount: shelf.items.count))
                }
            }
            if let message = shelf.message {
                Text(message).font(.system(size: 11)).selaSecondary().fixedSize(horizontal: false, vertical: true)
            }
        }.foregroundStyle(SelaTheme.ivory)
            .onAppear { shelf.refreshAvailability() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in shelf.refreshAvailability() }
    }
    private var rows: some View {
        LazyVStack(spacing: ShelfLayout.gap) {
            ForEach(shelf.items) { item in
                HStack(spacing: 8) {
                    ShelfDragItem(item: item, shelf: shelf)
                        .frame(maxWidth: .infinity).frame(height: 40)
                    Button { shelf.remove(item.id) } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .medium))
                            .frame(width: 28, height: 28)
                            .background(SelaTheme.raised, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain).disabled(shelf.isBusy)
                    .accessibilityLabel("Hapus titipan \(item.name)")
                    .help("Hapus titipan \(item.name)")
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(height: ShelfLayout.cardHeight)
                .background(SelaTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

}
#Preview("Shelf · Empty") { ShelfPanel(shelf: ShelfService(thumbnails: false)).padding(16).frame(width: 408).selaSurface() }
