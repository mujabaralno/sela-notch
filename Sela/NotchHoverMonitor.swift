import AppKit
import Foundation

@MainActor
final class NotchHoverMonitor {
    private let interval: TimeInterval = 0.08
    private var ticker: Timer?

    var onMouseMoved: ((CGPoint) -> Void)?

    func start() {
        guard ticker == nil else { return }

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.onMouseMoved?(NSEvent.mouseLocation)
            }
        }
        timer.tolerance = interval / 2
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
    }
}
