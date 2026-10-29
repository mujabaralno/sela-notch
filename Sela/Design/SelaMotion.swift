import SwiftUI

struct SelaArrival: ViewModifier {
    var delay: Double = 0
    @State private var visible = false
    @Environment(\.accessibilityReduceMotion) private var reduced
    func body(content: Content) -> some View {
        content.opacity(visible ? 1 : 0)
            .scaleEffect(visible || reduced ? 1 : 0.985, anchor: .top)
            .blur(radius: visible || reduced ? 0 : 2)
            .onAppear { withAnimation(SelaTheme.fade.delay(reduced ? 0 : delay)) { visible = true } }
    }
}

struct SelaMarquee: View {
    let text: String
    @State private var textWidth: CGFloat = 0
    @State private var travel = false
    @Environment(\.accessibilityReduceMotion) private var reduced
    var body: some View {
        GeometryReader { viewport in
            Text(text).font(.system(size: 15, weight: .semibold)).fixedSize()
                .background {
                    GeometryReader { measure in
                        Color.clear.preference(key: MarqueeWidth.self, value: measure.size.width)
                    }
                }
                .offset(x: travel && !reduced ? -max(0, textWidth - viewport.size.width) : 0)
                .animation(reduced || textWidth <= viewport.size.width ? nil : .linear(duration: max(6, Double(textWidth - viewport.size.width) / 18)).delay(2).repeatForever(autoreverses: true), value: travel)
                .onPreferenceChange(MarqueeWidth.self) { textWidth = $0 }
                .task(id: "\(text)-\(viewport.size.width)-\(textWidth)-\(reduced)") {
                    travel = false
                    await Task.yield()
                    travel = true
                }
        }.frame(height: 20).clipped().accessibilityLabel(text).help(text)
    }
}
private struct MarqueeWidth: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct SelaAlarmSymbol: View {
    @Environment(\.accessibilityReduceMotion) private var reduced
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.2, paused: reduced)) { context in
            Image(systemName: "bell.fill").foregroundStyle(SelaTheme.amber)
                .opacity(reduced ? 1 : 0.75 + 0.25 * sin(context.date.timeIntervalSinceReferenceDate * 3))
        }.accessibilityLabel("Sesi timer selesai")
    }
}
