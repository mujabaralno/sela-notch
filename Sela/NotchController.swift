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

    private lazy var notch = DynamicNotch(style: .auto) {
        AnyView(NotchContent())
    } compactLeading: {
        AnyView(
            Image(systemName: "sparkles")
                .foregroundStyle(.cyan)
        )
    } compactTrailing: {
        AnyView(
            Text("Sela")
                .font(.caption)
                .fontWeight(.semibold)
        )
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
