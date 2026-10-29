import AppKit
import SwiftUI

@MainActor
final class SyntheticDrag: NSObject, NSDraggingInfo {
    var draggingDestinationWindow: NSWindow?
    var draggingSourceOperationMask: NSDragOperation = .copy
    var draggingLocation = NSPoint.zero
    var draggedImageLocation = NSPoint.zero
    nonisolated var draggedImage: NSImage? { nil }
    let draggingPasteboard = NSPasteboard.withUniqueName()
    var draggingSource: Any? { nil }
    var draggingSequenceNumber = 1
    var draggingFormation: NSDraggingFormation = .none
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 1
    var springLoadingHighlight: NSSpringLoadingHighlight = .none
    func slideDraggedImage(to screenPoint: NSPoint) {}
    nonisolated override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }
    func resetSpringLoading() {}
    func enumerateDraggingItems(options: NSDraggingItemEnumerationOptions, for view: NSView?, classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey: Any], using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
}

@main
struct ShelfDropTests {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let urls = try (0..<13).map { index -> URL in
            let url = root.appendingPathComponent("drop-\(index).txt")
            try Data("sample".utf8).write(to: url)
            return url
        }
        let shelf = ShelfService(thumbnails: false)
        let view = ShelfDropView(shelf: shelf, content: Text("Synthetic destination"))
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 408, height: 188), styleMask: .borderless, backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.level = .screenSaver
        panel.contentView = view
        precondition(panel.level == .floating, "Drop receiver must lower screenSaver panel")
        let drag = SyntheticDrag()
        defer { drag.draggingPasteboard.releaseGlobally() }
        drag.draggingPasteboard.writeObjects(urls as [NSURL])
        precondition(view.draggingEntered(drag) == .copy && shelf.targeted)
        precondition(view.prepareForDragOperation(drag))
        precondition(view.performDragOperation(drag))
        precondition(shelf.items.count == 12 && shelf.message?.contains("penuh") == true && !shelf.targeted)
        precondition(urls.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
        drag.draggingSourceOperationMask = .move
        precondition(view.draggingEntered(drag).isEmpty, "Must never accept move-only transfer")
        drag.draggingSourceOperationMask = .copy
        _ = view.draggingEntered(drag)
        view.draggingExited(drag)
        precondition(!shelf.targeted && shelf.items.count == 12)
        view.restoreLevel()
        precondition(panel.level == .screenSaver)
        print("Shelf AppKit destination tests passed (synthetic drag, not Finder)")
    }
}
