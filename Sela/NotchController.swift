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
        AnyView(CompactMusicOrPet(timer: self.timer, battery: self.battery, music: self.music))
    } compactTrailing: {
        AnyView(CompactStatusLabel(timer: self.timer, battery: self.battery))
    }

    private let hoverMonitor = NotchHoverMonitor()
    private var cancellables = Set<AnyCancellable>()
    private var isExpanded = false
    private var isTransitioning = false
    private var compactRefreshPending = false
    private var enteredSinceOpen = false
    private var alertPresentationActive = false
    private var alertPresentationTask: Task<Void, Never>?
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
        if timer.showsCompactTime || music.isPlaying { compact() }
        else { hide() }
    }

    func expand() {
        guard !isExpanded, !isTransitioning else { return }

        isTransitioning = true
        isExpanded = true
        enteredSinceOpen = false
        alertPresentationTask?.cancel()
        alertPresentationTask = nil
        enterDate = nil
        leaveDate = nil
        status = .expanded

        Task {
            await notch.expand()
            isTransitioning = false
            if compactRefreshPending { refreshCompact() }
        }
    }

    func compact() {
        guard status != .compact, !isTransitioning else { return }

        isTransitioning = true
        isExpanded = false
        enteredSinceOpen = false
        alertPresentationActive = false
        alertPresentationTask?.cancel()
        alertPresentationTask = nil
        enterDate = nil
        leaveDate = nil
        panelRect = .null
        status = .compact

        Task {
            await notch.compact()
            isTransitioning = false
            if compactRefreshPending { refreshCompact() }
        }
    }

    func hide() {
        guard status != .hidden, !isTransitioning else { return }

        isTransitioning = true
        isExpanded = false
        enteredSinceOpen = false
        alertPresentationActive = false
        alertPresentationTask?.cancel()
        alertPresentationTask = nil
        enterDate = nil
        leaveDate = nil
        panelRect = .null
        status = .hidden

        Task {
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
        if timer.showsCompactTime || music.isPlaying {
            compact()
        } else {
            hide()
        }
    }

    private func handleBatteryAlert(_ alert: BatteryAlert?) {
        guard alert != nil else {
            restoreAfterAlert()
            return
        }

        guard !alertPresentationActive, status != .expanded else { return }

        alertPresentationActive = true
        presentAlertPanel(attempt: 0)
    }

    private func presentAlertPanel(attempt: Int) {
        guard alertPresentationActive, battery.alert != nil else { return }
        guard status != .expanded else { return }

        guard !isTransitioning else {
            guard attempt < 15 else {
                alertPresentationActive = false
                return
            }

            scheduleAlertStep { [weak self] in
                self?.presentAlertPanel(attempt: attempt + 1)
            }
            return
        }

        alertPresentationTask = nil
        expand()
    }

    private func restoreAfterAlert(attempt: Int = 0) {
        guard alertPresentationActive, battery.alert == nil else { return }

        if enteredSinceOpen || isMouseInsidePanelArea {
            alertPresentationActive = false
            return
        }

        guard !isTransitioning else {
            guard attempt < 15 else {
                alertPresentationActive = false
                return
            }

            scheduleAlertStep { [weak self] in
                self?.restoreAfterAlert(attempt: attempt + 1)
            }
            return
        }

        alertPresentationActive = false
        alertPresentationTask?.cancel()
        alertPresentationTask = nil

        if timer.showsCompactTime || music.isPlaying {
            compact()
        } else {
            hide()
        }
    }

    private func scheduleAlertStep(_ action: @escaping @MainActor () -> Void) {
        alertPresentationTask?.cancel()
        alertPresentationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            action()
        }
    }

    private var isMouseInsidePanelArea: Bool {
        let point = NSEvent.mouseLocation
        return Self.activationRect.contains(point)
            || notch.isHovering
            || panelRect.insetBy(dx: -12, dy: -12).contains(point)
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

    var body: some View {
        VStack(spacing: 6) {
            BatteryAlertBanner(battery: battery)

            HStack {
                Button("Timer") { selection.select(0) }
                Button("Baterai") { selection.select(1) }
                Button("Music") { selection.select(2) }
            }
            if selection.index == 2 {
                MusicPanel(music: music)
            } else if selection.index == 0 {
                TimerPanel(timer: timer)
            } else {
                BatteryPanel(battery: battery)
            }
        }
    }
}

struct CompactMusicOrPet: View {
    @ObservedObject var timer: TimerModel
    @ObservedObject var battery: BatteryModel
    @ObservedObject var music: MusicService
    var body: some View {
        if !timer.showsCompactTime && battery.alert == nil && music.isPlaying {
            MusicArtwork(image: music.snapshot?.artwork)
        } else { CompactPet(timer: timer) }
    }
}
