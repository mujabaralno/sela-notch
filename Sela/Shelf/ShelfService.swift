import AppKit
import Combine
import QuickLookThumbnailing

struct ShelfItem: Identifiable {
    let id: UUID
    let url: URL
    var thumbnail: NSImage?
    var available: Bool
    var name: String { url.lastPathComponent }
}

/// Temporary references only. Never copies, moves, deletes or persists a file.
@MainActor
final class ShelfService: ObservableObject {
    static let capacity = 12
    @Published private(set) var items: [ShelfItem] = []
    @Published private(set) var message: String?
    @Published var externalDrag = false
    @Published var outgoingDrag = false
    @Published var targeted = false
    @Published private(set) var receiving = false
    var isBusy: Bool { externalDrag || outgoingDrag || targeted || receiving }
    private let thumbnails: Bool
    private var requests: [UUID: QLThumbnailGenerator.Request] = [:]
    init(thumbnails: Bool = true) { self.thumbnails = thumbnails }

    @discardableResult func add(_ urls: [URL]) -> Int {
        receiving = true
        defer { receiving = false }
        var added = 0, overflow = 0, unavailable = 0
        for url in urls where url.isFileURL {
            let url = url.standardizedFileURL
            guard !items.contains(where: { $0.url == url }) else { continue }
            guard FileManager.default.isReadableFile(atPath: url.path) else { unavailable += 1; continue }
            guard items.count < Self.capacity else { overflow += 1; continue }
            let item = ShelfItem(id: UUID(), url: url, available: true)
            items.append(item)
            added += 1
            if thumbnails { requestThumbnail(item) }
        }
        if overflow > 0 { message = "Shelf penuh · \(overflow) file tidak ditambahkan (maks. 12)." }
        else if unavailable > 0 { message = "\(unavailable) file tidak dapat diakses." }
        else { message = added > 0 ? "\(added) file dititipkan · file asli tetap di tempatnya." : "File sudah ada di Shelf atau tidak tersedia." }
        return added
    }
    func refreshAvailability() {
        for index in items.indices {
            items[index].available = FileManager.default.isReadableFile(atPath: items[index].url.path)
        }
    }
    func remove(_ id: UUID) {
        guard !isBusy else { return }
        if let request = requests.removeValue(forKey: id) { QLThumbnailGenerator.shared.cancel(request) }
        items.removeAll { $0.id == id }
        message = nil
    }
    func clear() {
        guard !isBusy else { return }
        requests.values.forEach { QLThumbnailGenerator.shared.cancel($0) }
        requests.removeAll()
        items.removeAll()
        message = nil
    }
    private func requestThumbnail(_ item: ShelfItem) {
        let request = QLThumbnailGenerator.Request(fileAt: item.url, size: CGSize(width: 64, height: 64), scale: 2, representationTypes: .all)
        requests[item.id] = request
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            Task { @MainActor in
                guard let self, self.requests.removeValue(forKey: item.id) != nil,
                      let index = self.items.firstIndex(where: { $0.id == item.id }) else { return }
                if let representation { self.items[index].thumbnail = NSImage(cgImage: representation.cgImage, size: CGSize(width: 64, height: 64)) }
            }
        }
    }
}

/// Uses the existing hover ticker; no new timer, keyboard monitor or permission.
struct ShelfDragObservation {
    private var lastCount = NSPasteboard(name: .drag).changeCount
    private(set) var draggingFiles = false
    mutating func update(changeCount: Int, hasFiles: Bool, mouseDown: Bool) -> Bool {
        if !mouseDown { draggingFiles = false }
        else if changeCount != lastCount { draggingFiles = hasFiles }
        lastCount = changeCount
        return draggingFiles
    }
}
