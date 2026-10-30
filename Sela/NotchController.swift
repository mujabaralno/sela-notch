import Combine
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

    let shelf = ShelfService()
    private var dragObservation = ShelfDragObservation()
    let music = MusicService(provider: MediaRemoteMusicProvider())
    let calendar = CalendarService(provider: EventKitCalendarProvider())
    let inbox = InboxService.shared
    let timer = TimerModel()
    let battery = BatteryModel()
    let selection = NotchPanelSelection()
    @Published var selectedPanel = 0 {
        didSet { selection.select(selectedPanel) }
    }

    private static let openDwell: TimeInterval = 0.12
    private static let closeGrace: TimeInterval = 0.5

    private lazy var notch = DynamicNotch(style: .auto) {
        AnyView(
            NotchExpandedContent(
                selection: self.selection,
                timer: self.timer,
                battery: self.battery,
                music: self.music,
                shelf: self.shelf,
                calendar: self.calendar,
                inbox: self.inbox
            )
            .reportsInteractionArea { self.updatePanelRect($0) }
        )
    } compactLeading: {
        AnyView(SelaCompactWing(timer: self.timer, battery: self.battery, music: self.music, shelf: self.shelf, inbox: self.inbox, leading: true))
    } compactTrailing: {
        AnyView(SelaCompactWing(timer: self.timer, battery: self.battery, music: self.music, shelf: self.shelf, inbox: self.inbox, leading: false))
    }

    private let hoverMonitor = NotchHoverMonitor()
    private let floatingPanel = FloatingSelaPanel()
    private var cancellables = Set<AnyCancellable>()
    private var isExpanded = false
    private var isTransitioning = false
    private var compactRefreshPending = false
    private var enteredSinceOpen = false
    private var enterDate: Date?
    private var leaveDate: Date?
    private var panelRect: CGRect = .null

    init() {
        hoverMonitor.onMouseMoved = { [weak self] point in
            self?.handleMouse(at: point)
        }
        hoverMonitor.start()
        music.start()
        calendar.start()
        shelf.$items.sink { [weak self] _ in
            Task { @MainActor in self?.refreshCompact() }
        }.store(in: &cancellables)
        inbox.$items.sink { [weak self] _ in
            Task { @MainActor in self?.refreshCompact() }
        }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.music.stop()
                    self?.calendar.stop()
                }
            }.store(in: &cancellables)
        selection.$index
            .removeDuplicates()
            .sink { [weak self] index in
                Task { @MainActor in
                    guard let self else { return }
                    if index == SelaPanel.calendar.rawValue { await self.calendar.refresh() }
                    if index == SelaPanel.inbox.rawValue { self.inbox.markAllRead() }
                }
            }.store(in: &cancellables)
        music.$snapshot.sink { [weak self] _ in
            Task { @MainActor in self?.refreshCompact() }
        }.store(in: &cancellables)
        timer.$phase.sink { [weak self] _ in
            Task { @MainActor in self?.refreshCompact() }
        }.store(in: &cancellables)

        battery.$alert
            .sink { [weak self] alert in
                Task { @MainActor in
                    self?.handleBatteryAlert(alert)
                }
            }
            .store(in: &cancellables)
    }

    private func refreshCompact() {
        guard !isExpanded, !shelf.isBusy else { return }
        guard !isTransitioning else { compactRefreshPending = true; return }
        compactRefreshPending = false
        if SelaLiveActivity.resolve(timer: timer, battery: battery, music: music, shelf: shelf, inbox: inbox) != .idle { compact() }
        else { hide() }
    }

    private func configureMotion() {
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        notch.transitionConfiguration = .init(openingAnimation: reduced ? .linear(duration: 0) : SelaTheme.spring,
            closingAnimation: reduced ? .linear(duration: 0) : SelaTheme.fade, conversionAnimation: reduced ? .linear(duration: 0) : SelaTheme.spring,
            skipIntermediateHides: true)
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
            configureMotion()
            let screen = presentationScreen
            if screen.safeAreaInsets.top > 0 {
                floatingPanel.hide()
                await notch.expand(on: screen)
            } else {
                await notch.hide()
                floatingPanel.show(content: AnyView(NotchExpandedContent(selection: selection, timer: timer, battery: battery, music: music, shelf: shelf, calendar: calendar, inbox: inbox)
                    .clipShape(RoundedRectangle(cornerRadius: SelaTheme.radius))), screen: screen)
                panelRect = floatingPanel.frame
            }
            isTransitioning = false
            if compactRefreshPending { refreshCompact() }
        }
    }

    func compact() {
        guard status != .compact, !isTransitioning, !shelf.isBusy else { return }

        isTransitioning = true
        isExpanded = false
        enteredSinceOpen = false
        enterDate = nil
        leaveDate = nil
        panelRect = .null
        status = .compact

        Task {
            configureMotion()
            let screen = presentationScreen
            if screen.safeAreaInsets.top > 0 {
                floatingPanel.hide()
                await notch.compact(on: screen)
            } else {
                await notch.hide()
                floatingPanel.show(content: AnyView(HStack(spacing: 16) {
                    SelaCompactWing(timer: timer, battery: battery, music: music, shelf: shelf, inbox: inbox, leading: true)
                    SelaCompactWing(timer: timer, battery: battery, music: music, shelf: shelf, inbox: inbox, leading: false)
                }.padding(.horizontal, 16).frame(width: 112, height: 36).selaSurface().clipShape(Capsule())), screen: screen)
                panelRect = floatingPanel.frame
            }
            isTransitioning = false
            if compactRefreshPending { refreshCompact() }
        }
    }

    func hide() {
        guard status != .hidden, !isTransitioning, !shelf.isBusy else { return }

        isTransitioning = true
        isExpanded = false
        enteredSinceOpen = false
        enterDate = nil
        leaveDate = nil
        panelRect = .null
        status = .hidden

        Task {
            floatingPanel.hide()
            await notch.hide()
            isTransitioning = false
            if compactRefreshPending { refreshCompact() }
        }
    }

    private func handleMouse(at point: CGPoint) {
        let dragBoard = NSPasteboard(name: .drag)
        let dragging = dragObservation.update(changeCount: dragBoard.changeCount,
            hasFiles: dragBoard.types?.contains(.fileURL) == true,
            mouseDown: NSEvent.pressedMouseButtons & 1 != 0)
        if shelf.externalDrag != dragging { shelf.externalDrag = dragging }
        guard !isTransitioning else { return }

        let inActivation = Self.activationRect.contains(point)
        let inPanel = isExpanded && (notch.isHovering || panelRect.insetBy(dx: -12, dy: -12).contains(point))

        if shelf.externalDrag && !shelf.outgoingDrag && (inActivation || inPanel) {
            selection.index = SelaPanel.shelf.rawValue
            expand()
            enteredSinceOpen = true
            leaveDate = nil
        }
        // Retain the panel even beyond its bounds until AppKit ends the session.
        if shelf.isBusy { leaveDate = nil; return }

        if inActivation || inPanel {
            leaveDate = nil

            if isExpanded {
                enteredSinceOpen = true
                enterDate = nil
            } else {
                let enteredAt = enterDate ?? Date()
                enterDate = enteredAt

                if Date().timeIntervalSince(enteredAt) >= Self.openDwell {
                    if music.isPlaying && !timer.showsCompactTime && battery.alert == nil {
                        selection.index = SelaPanel.music.rawValue
                    } else { selection.index = selection.manualIndex }
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
        if SelaLiveActivity.resolve(timer: timer, battery: battery, music: music, shelf: shelf, inbox: inbox) != .idle {
            compact()
        } else {
            hide()
        }
    }

    private func handleBatteryAlert(_ alert: BatteryAlert?) {
        refreshCompact()
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

    private var presentationScreen: NSScreen {
        NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.screens[0]
    }

    private static var activationRect: CGRect {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main ?? NSScreen.screens.first else { return .null }

        if let housing = cameraHousingRect(for: screen) {
            return housing
        }

        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        let width: CGFloat = 156

        return CGRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - menuBarHeight,
            width: width,
            height: menuBarHeight
        )
    }

    private static func cameraHousingRect(for screen: NSScreen) -> CGRect? {
        guard screen.safeAreaInsets.top > 0,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea
        else { return nil }

        let width = screen.frame.width - left.width - right.width
        guard width > 0 else { return nil }

        return CGRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - screen.safeAreaInsets.top,
            width: width,
            height: screen.safeAreaInsets.top
        )
    }
}

@MainActor
final class NotchPanelSelection: ObservableObject {
    @Published var index = 0
    private(set) var manualIndex = 0
    func select(_ index: Int) {
        manualIndex = index
        self.index = index
    }
}

struct NotchExpandedContent: View {
    @ObservedObject var selection: NotchPanelSelection
    let timer: TimerModel
    let battery: BatteryModel
    let music: MusicService
    @ObservedObject var shelf: ShelfService
    let calendar: CalendarService
    let inbox: InboxService

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ShelfDropContainer(shelf: shelf) {
            content.frame(width: SelaTheme.width, height: contentHeight, alignment: .top)
        }
            .onChange(of: shelf.targeted) { targeted in
                if targeted && !shelf.outgoingDrag { selection.index = SelaPanel.shelf.rawValue }
            }
            .frame(width: SelaTheme.width, height: contentHeight)
    }
    private var contentHeight: CGFloat {
        switch SelaPanel(rawValue: selection.index) {
        case .shelf:
            ShelfLayout.panelHeight(itemCount: shelf.items.count, hasMessage: shelf.message != nil)
        case .calendar:
            CalendarLayout.contentHeight
        case .inbox:
            InboxLayout.contentHeight
        default:
            188
        }
    }
    private var content: some View {
        VStack(spacing: 12) {
            SelaNavigation(selection: selection).disabled(shelf.isBusy).modifier(SelaArrival())
            Group {
                switch SelaPanel(rawValue: selection.index) {
                case .shelf: ShelfPanel(shelf: shelf)
                case .calendar: CalendarPanel(calendar: calendar)
                case .inbox: InboxPanel(inbox: inbox)
                case .music: MusicPanel(music: music)
                case .timer: TimerPanel(timer: timer)
                case .battery, .none: BatteryPanel(battery: battery)
                }
            }
            .modifier(SelaArrival(delay: 0.06))
            .id(selection.index)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
        }
        .padding(16)
        .frame(width: SelaTheme.width)
        .selaSurface()
        .overlay {
            if shelf.targeted {
                RoundedRectangle(cornerRadius: 20).strokeBorder(SelaTheme.green, style: StrokeStyle(lineWidth: 2, dash: [6, 4])).allowsHitTesting(false)
            }
        }
    }
}
