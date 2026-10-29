import AppKit
import SwiftUI

/// A parent drop destination rather than an overlay: child buttons and outgoing
/// drags receive normal hit tests. The hosting frame is exactly rendered content.
struct ShelfDropContainer<Content: View>: NSViewRepresentable {
    let shelf: ShelfService
    let content: Content
    init(shelf: ShelfService, @ViewBuilder content: () -> Content) { self.shelf = shelf; self.content = content() }
    func makeNSView(context: Context) -> ShelfDropView<Content> { ShelfDropView(shelf: shelf, content: content) }
    func updateNSView(_ view: ShelfDropView<Content>, context: Context) {
        view.host.rootView = content
        view.invalidateIntrinsicContentSize()
    }
    static func dismantleNSView(_ view: ShelfDropView<Content>, coordinator: ()) { view.restoreLevel() }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: ShelfDropView<Content>, context: Context) -> CGSize? {
        // Respect the shell's explicit dimensions instead of letting nested
        // hosting views negotiate an oversized intrinsic height.
        if let width = proposal.width, let height = proposal.height {
            return CGSize(width: width, height: height)
        }
        return nsView.host.fittingSize
    }
}

final class ShelfDropView<Content: View>: NSView {
    let host: NSHostingView<Content>
    let shelf: ShelfService
    private weak var loweredWindow: NSWindow?
    private var originalLevel: NSWindow.Level?
    init(shelf: ShelfService, content: Content) {
        self.shelf = shelf
        host = NSHostingView(rootView: content)
        super.init(frame: .zero)
        addSubview(host)
        host.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([host.leadingAnchor.constraint(equalTo: leadingAnchor), host.trailingAnchor.constraint(equalTo: trailingAnchor), host.topAnchor.constraint(equalTo: topAnchor), host.bottomAnchor.constraint(equalTo: bottomAnchor)])
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var intrinsicContentSize: NSSize { host.fittingSize }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        restoreLevel()
        if let window, window is NSPanel {
            loweredWindow = window
            originalLevel = window.level
            window.level = .floating
        }
    }
    func restoreLevel() {
        if let originalLevel { loweredWindow?.level = originalLevel }
        originalLevel = nil
        loweredWindow = nil
    }
    private func files(_ sender: NSDraggingInfo) -> [URL] {
        (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []).filter(\.isFileURL)
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingSourceOperationMask.contains(.copy), !files(sender).isEmpty else { return [] }
        shelf.targeted = true
        return .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { shelf.targeted ? .copy : [] }
    override func draggingExited(_ sender: NSDraggingInfo?) { shelf.targeted = false }
    override func draggingEnded(_ sender: NSDraggingInfo) { shelf.targeted = false }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { shelf.targeted }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = files(sender)
        shelf.add(urls)
        shelf.targeted = false
        return !urls.isEmpty // capacity rejection is explained by Shelf, never move originals
    }
}
