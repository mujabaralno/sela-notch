import SwiftUI

/// Shared presentation tokens. All measurements follow a four-point grid.
enum SelaTheme {
    static let black = Color.black
    static let surface = Color(red: 17/255, green: 17/255, blue: 16/255)
    static let raised = Color(red: 29/255, green: 29/255, blue: 26/255)
    static let ivory = Color(red: 244/255, green: 241/255, blue: 233/255)
    static let green = Color(red: 0.65, green: 0.79, blue: 0.65)
    static let amber = Color(red: 0.88, green: 0.70, blue: 0.46)
    static let rest = Color(red: 0.67, green: 0.75, blue: 0.81)
    static let width: CGFloat = 408
    static let radius: CGFloat = 24
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let fade = Animation.easeInOut(duration: 0.18)
}

struct SelaSecondary: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        content.foregroundStyle(SelaTheme.ivory.opacity(contrast == .increased ? 0.85 : 0.62))
    }
}
extension View {
    func selaSecondary() -> some View { modifier(SelaSecondary()) }
    func selaSurface() -> some View {
        foregroundStyle(SelaTheme.ivory).background(SelaTheme.black).preferredColorScheme(.dark)
    }
}

struct SelaButtonStyle: ButtonStyle {
    var prominent = false
    @State private var hovering = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .frame(minWidth: 36, minHeight: 36)
            .padding(.horizontal, 8)
            .foregroundStyle(prominent ? SelaTheme.black : SelaTheme.ivory)
            .background(prominent ? SelaTheme.ivory : (hovering ? SelaTheme.ivory.opacity(0.18) : SelaTheme.raised), in: RoundedRectangle(cornerRadius: 12))
            .onHover { hovering = $0 }
            .opacity(enabled ? (configuration.isPressed ? 0.72 : 1) : 0.35)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? SelaTheme.fade : SelaTheme.spring, value: configuration.isPressed)
    }
}

struct SelaIconButton: View {
    let symbol: String
    let label: String
    var prominent = false
    let action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 15, weight: .medium)) }
            .buttonStyle(SelaButtonStyle(prominent: prominent))
            .accessibilityLabel(label).help(label)
    }
}

struct SelaRing: View {
    let progress: Double
    var tint: Color = SelaTheme.ivory
    var lineWidth: CGFloat = 4
    var body: some View {
        Circle().stroke(SelaTheme.raised, lineWidth: lineWidth)
            .overlay {
                Circle().trim(from: 0, to: min(1, max(0, progress)))
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .accessibilityHidden(true)
    }
}

struct SelaProgress: View {
    let progress: Double
    var tint: Color = SelaTheme.ivory
    var body: some View {
        GeometryReader { proxy in
            Capsule().fill(SelaTheme.raised)
                .overlay(alignment: .leading) {
                    Capsule().fill(tint).frame(width: proxy.size.width * min(1, max(0, progress)))
                }
        }.frame(height: 4).accessibilityHidden(true)
    }
}

/// Preview / companion-window silhouette. Hardware chrome is owned by DynamicNotchKit.
struct SelaNotchShape: Shape {
    func path(in r: CGRect) -> Path {
        let shoulder: CGFloat = 12
        let radius: CGFloat = 24
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addQuadCurve(to: CGPoint(x: shoulder, y: shoulder), control: CGPoint(x: shoulder, y: 0))
        p.addLine(to: CGPoint(x: shoulder, y: r.maxY - radius))
        p.addQuadCurve(to: CGPoint(x: shoulder + radius, y: r.maxY), control: CGPoint(x: shoulder, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - shoulder - radius, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - shoulder, y: r.maxY - radius), control: CGPoint(x: r.maxX - shoulder, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - shoulder, y: shoulder))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: 0), control: CGPoint(x: r.maxX - shoulder, y: 0))
        p.closeSubpath()
        return p
    }
}

#Preview("Components") {
    HStack(spacing: 24) {
        SelaRing(progress: 0.64).frame(width: 64, height: 64)
        SelaIconButton(symbol: "play.fill", label: "Mulai", prominent: true) {}
        SelaProgress(progress: 0.64).frame(width: 100)
    }.padding(32).selaSurface()
}
