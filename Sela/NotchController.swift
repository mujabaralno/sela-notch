import DynamicNotchKit
import SwiftUI

@MainActor
final class NotchController: ObservableObject {
    enum Status: String {
        case hidden = "Tersembunyi"
        case expanded = "Terbuka"
        case compact = "Ringkas"
    }

    @Published private(set) var status: Status = .hidden

    let timer = TimerModel()

    private static let openDwell: TimeInterval = 0.12
    private static let closeGrace: TimeInterval = 0.5

    private lazy var notch = DynamicNotch(style: .auto) {
        AnyView(
            TimerPanel(timer: self.timer)
                .reportsInteractionArea { self.updatePanelRect($0) }
        )
    } compactLeading: {
        AnyView(PetView(timer: self.timer, height: 16))
    } compactTrailing: {
        AnyView(CompactTimerLabel(timer: self.timer))
    }

    private let hoverMonitor = NotchHoverMonitor()
    private var isExpanded = false
    private var isTransitioning = false
    private var enteredSinceOpen = false
    private var enterDate: Date?
    private var leaveDate: Date?
    private var panelRect: CGRect = .null

    init() {
        hoverMonitor.onMouseMoved = { [weak self] point in
            self?.handleMouse(at: point)
        }
        hoverMonitor.start()
    }

    func expand() {
        guard !isExpanded, !isTransitioning else { return }

        isTransitioning = true
        isExpanded = true
        enteredSinceOpen = false
        enterDate = nil
        leaveDate = nil
        status = .expanded

        Task {
            await notch.expand()
            isTransitioning = false
        }
    }

    func compact() {
        guard status != .compact, !isTransitioning else { return }

        isTransitioning = true
        isExpanded = false
        enteredSinceOpen = false
        enterDate = nil
        leaveDate = nil
        panelRect = .null
        status = .compact

        Task {
            await notch.compact()
            isTransitioning = false
        }
    }

    func hide() {
        guard status != .hidden, !isTransitioning else { return }

        isTransitioning = true
        isExpanded = false
        enteredSinceOpen = false
        enterDate = nil
        leaveDate = nil
        panelRect = .null
        status = .hidden

        Task {
            await notch.hide()
            isTransitioning = false
        }
    }

    private func handleMouse(at point: CGPoint) {
        guard !isTransitioning else { return }

        let inActivation = Self.activationRect.contains(point)
        let inPanel = notch.isHovering || panelRect.insetBy(dx: -12, dy: -12).contains(point)

        if inActivation || inPanel {
            leaveDate = nil

            if isExpanded {
                enteredSinceOpen = true
                enterDate = nil
            } else {
                let enteredAt = enterDate ?? Date()
                enterDate = enteredAt

                if Date().timeIntervalSince(enteredAt) >= Self.openDwell {
                    expand()
                }
            }
            return
        }

        enterDate = nil

        guard isExpanded, enteredSinceOpen else {
            leaveDate = nil
            return
        }

        guard let leftAt = leaveDate else {
            leaveDate = Date()
            return
        }

        guard Date().timeIntervalSince(leftAt) >= Self.closeGrace else { return }

        leaveDate = nil
        if timer.isActive {
            compact()
        } else {
            hide()
        }
    }

    private func updatePanelRect(_ frame: CGRect, attempt: Int = 0) {
        guard let window = notch.windowController?.window,
              let screen = window.screen ?? NSScreen.main else {
            guard attempt < 10 else { return }

            Task {
                try? await Task.sleep(for: .milliseconds(50))
                updatePanelRect(frame, attempt: attempt + 1)
            }
            return
        }

        let topLeftX = window.frame.minX + frame.minX
        let topLeftY = screen.frame.maxY - window.frame.maxY + frame.minY

        panelRect = CGRect(
            x: topLeftX,
            y: screen.frame.maxY - (topLeftY + frame.height),
            width: frame.width,
            height: frame.height
        )
    }

    private static var activationRect: CGRect {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return .null }

        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        let height = menuBarHeight + 6
        let width: CGFloat = 220

        return CGRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
    }
}
