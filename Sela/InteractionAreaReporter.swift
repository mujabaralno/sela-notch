import SwiftUI

struct InteractionAreaReporter: ViewModifier {
    let onUpdate: (CGRect) -> Void

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .global)

                Color.clear
                    .task(id: frame) {
                        onUpdate(frame)
                    }
            }
        }
    }
}

extension View {
    func reportsInteractionArea(_ onUpdate: @escaping (CGRect) -> Void) -> some View {
        modifier(InteractionAreaReporter(onUpdate: onUpdate))
    }
}
