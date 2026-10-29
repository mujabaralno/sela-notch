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

    private lazy var notch = DynamicNotch(style: .auto) {
        AnyView(TimerPanel(timer: self.timer))
    } compactLeading: {
        AnyView(
            Image(systemName: "timer")
                .foregroundStyle(.cyan)
        )
    } compactTrailing: {
        AnyView(CompactTimerLabel(timer: self.timer))
    }

    func expand() {
        Task {
            await notch.expand()
            status = .expanded
        }
    }

    func compact() {
        Task {
            await notch.compact()
            status = .compact
        }
    }

    func hide() {
        Task {
            await notch.hide()
            status = .hidden
        }
    }
}
