import SwiftUI
import AppKit

struct ShelfDragItem: NSViewRepresentable {
    let item: ShelfItem
    let shelf: ShelfService
    func makeNSView(context: Context) -> ShelfFileView { ShelfFileView(item: item, shelf: shelf) }
    func updateNSView(_ view: ShelfFileView, context: Context) { view.update(item) }
}
final class ShelfFileView: NSView, NSDraggingSource {
    private var item: ShelfItem
    private let shelf: ShelfService
    private let image = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private let status = NSTextField(labelWithString: "")
    init(item: ShelfItem, shelf: ShelfService) {
        self.item = item; self.shelf = shelf
        super.init(frame: .zero)
        for child in [image, title, status] { addSubview(child) }
        title.font = .systemFont(ofSize: 11, weight: .medium)
        title.textColor = NSColor(SelaTheme.ivory)
        title.lineBreakMode = .byTruncatingMiddle
        status.font = .systemFont(ofSize: 11)
        status.textColor = NSColor(SelaTheme.ivory).withAlphaComponent(0.62)
        image.imageScaling = .scaleProportionallyUpOrDown
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        update(item)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func update(_ item: ShelfItem) {
        self.item = item
        image.image = item.thumbnail ?? NSWorkspace.shared.icon(forFile: item.url.path)
        image.alphaValue = item.available ? 1 : 0.4
        title.stringValue = item.name
        status.textColor = NSColor(item.available ? SelaTheme.ivory.opacity(0.62) : SelaTheme.amber)
        status.stringValue = item.available ? "Tarik untuk menyalin" : "File tidak tersedia"
        setAccessibilityLabel("\(item.name), \(status.stringValue)")
        toolTip = "\(item.name) — \(status.stringValue)"
    }
    override func layout() {
        super.layout()
        image.frame = NSRect(x: 0, y: 8, width: 24, height: 24)
        title.frame = NSRect(x: 32, y: 20, width: max(0, bounds.width - 32), height: 16)
        status.frame = NSRect(x: 32, y: 4, width: max(0, bounds.width - 32), height: 16)
    }
    override func hitTest(_ point: NSPoint) -> NSView? { bounds.contains(point) ? self : nil }
    override func mouseDown(with event: NSEvent) { }
    override func mouseDragged(with event: NSEvent) {
        guard FileManager.default.isReadableFile(atPath: item.url.path), !shelf.outgoingDrag else {
            shelf.refreshAvailability(); return
        }
        let dragItem = NSDraggingItem(pasteboardWriter: item.url as NSURL)
        dragItem.setDraggingFrame(image.frame, contents: image.image)
        shelf.outgoingDrag = true
        let session = beginDraggingSession(with: [dragItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        shelf.outgoingDrag = false
        shelf.refreshAvailability()
    }
    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
}
