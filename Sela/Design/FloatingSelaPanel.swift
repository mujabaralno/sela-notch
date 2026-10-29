import AppKit
import SwiftUI

/// Presentation-only fallback. Its frame is exactly the visible pill, with no
/// transparent hover capture area. Feature state stays in the existing models.
@MainActor
final class FloatingSelaPanel {
    private let panel: NSPanel = {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        return panel
    }()
    var frame: CGRect { panel.frame }
    func show(content: AnyView, screen: NSScreen) {
        let view = NSHostingView(rootView: content.preferredColorScheme(.dark))
        let size = view.fittingSize
        panel.contentView = view
        let topInset = max(24, screen.frame.maxY - screen.visibleFrame.maxY)
        panel.setFrame(CGRect(x: screen.frame.midX - size.width / 2,
                              y: screen.frame.maxY - topInset - size.height - 8,
                              width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
    }
    func hide() { panel.orderOut(nil) }
}
