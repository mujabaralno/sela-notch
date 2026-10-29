import AppKit

@main
struct ShelfServiceTests {
    @MainActor static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let files = try (0..<14).map { index -> URL in
            let url = root.appendingPathComponent("sample-\(index).txt")
            try Data("synthetic file \(index)".utf8).write(to: url)
            return url
        }
        let shelf = ShelfService(thumbnails: false)
        precondition(shelf.add([files[0], files[0]]) == 1)
        precondition(shelf.add(Array(files[1...])) == 11)
        precondition(shelf.items.count == 12 && shelf.message?.contains("penuh") == true)
        precondition(shelf.items.map(\.url) == Array(files.prefix(12)))
        precondition(shelf.add([URL(string: "https://example.com/test")!]) == 0)
        shelf.outgoingDrag = true
        let first = shelf.items[0]
        shelf.remove(first.id)
        shelf.clear()
        precondition(shelf.items.count == 12 && shelf.isBusy)
        shelf.outgoingDrag = false // cancellation or successful drop never removes item
        precondition(shelf.items[0].id == first.id)
        shelf.remove(first.id)
        precondition(shelf.items.count == 11 && FileManager.default.fileExists(atPath: files[0].path))
        precondition(shelf.add([files[12]]) == 1)
        try FileManager.default.moveItem(at: files[1], to: root.appendingPathComponent("moved.txt"))
        shelf.refreshAvailability()
        precondition(shelf.items.first(where: { $0.url == files[1] })?.available == false)
        shelf.clear()
        precondition(shelf.items.isEmpty)
        precondition(FileManager.default.fileExists(atPath: files[12].path))
        let content = try String(contentsOf: files[12], encoding: .utf8)
        precondition(content == "synthetic file 12")
        var observer = ShelfDragObservation()
        precondition(!observer.update(changeCount: 100, hasFiles: true, mouseDown: false))
        precondition(!observer.update(changeCount: 100, hasFiles: true, mouseDown: true), "Stale pasteboard must not activate a file drag")
        precondition(observer.update(changeCount: 101, hasFiles: true, mouseDown: true))
        precondition(observer.update(changeCount: 101, hasFiles: true, mouseDown: true))
        precondition(!observer.update(changeCount: 101, hasFiles: true, mouseDown: false))
        precondition(!observer.update(changeCount: 102, hasFiles: false, mouseDown: true))
        print("Shelf service and drag observation tests passed (synthetic files)")
    }
}
