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

    let music = MusicService(provider: MediaRemoteMusicProvider())
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
                music: self.music
            )
            .reportsInteractionArea { self.updatePanelRect($0) }
        )
    } compactLeading: {
        AnyView(SelaCompactWing(timer: self.timer, battery: self.battery, music: self.music, leading: true))
    } compactTrailing: {
        AnyView(SelaCompactWing(timer: self.timer, battery: self.battery, music: self.music, leading: false))
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
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.music.stop() }
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
        guard !isExpanded else { return }
        guard !isTransitioning else { compactRefreshPending = true; return }
        compactRefreshPending = false
        if SelaLiveActivity.resolve(timer: timer, battery: battery, music: music) != .idle { compact() }
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
                floatingPanel.show(content: AnyView(NotchExpandedContent(selection: selection, timer: timer, battery: battery, music: music)
                    .clipShape(RoundedRectangle(cornerRadius: SelaTheme.radius))), screen: screen)
                panelRect = floatingPanel.frame
            }
            isTransitioning = false
            if compactRefreshPending { refreshCompact() }
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
            configureMotion()
            let screen = presentationScreen
            if screen.safeAreaInsets.top > 0 {
                floatingPanel.hide()
                await notch.compact(on: screen)
            } else {
                await notch.hide()
                floatingPanel.show(content: AnyView(HStack(spacing: 16) {
                    SelaCompactWing(timer: timer, battery: battery, music: music, leading: true)
                    SelaCompactWing(timer: timer, battery: battery, music: music, leading: false)
                }.padding(.horizontal, 16).frame(width: 112, height: 36).selaSurface().clipShape(Capsule())), screen: screen)
                panelRect = floatingPanel.frame
            }
            isTransitioning = false
            if compactRefreshPending { refreshCompact() }
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
            floatingPanel.hide()
            await notch.hide()
            isTransitioning = false
            if compactRefreshPending { refreshCompact() }
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
                    if music.isPlaying && !timer.showsCompactTime && battery.alert == nil {
                        selection.index = 2
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
        if SelaLiveActivity.resolve(timer: timer, battery: battery, music: music) != .idle {
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 12) {
            SelaNavigation(selection: selection).modifier(SelaArrival())
            Group {
                if selection.index == 2 { MusicPanel(music: music) }
                else if selection.index == 0 { TimerPanel(timer: timer) }
                else { BatteryPanel(battery: battery) }
            }
            .modifier(SelaArrival(delay: 0.06))
            .id(selection.index)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
        }
        .padding(16)
        .frame(width: SelaTheme.width)
        .selaSurface()
    }
}
