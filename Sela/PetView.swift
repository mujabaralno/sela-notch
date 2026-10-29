import SwiftUI

struct PetView: View {
    @ObservedObject var timer: TimerModel
    var height: CGFloat = 50
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let frames = PetSpriteSheet.shared.frames

    var body: some View {
        content
            .frame(width: height * 0.92, height: height)
            .opacity(timer.phase == .running ? 1 : 0.8)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        if frames.isEmpty {
            Image(systemName: "sparkles")
                .foregroundStyle(.secondary)
        } else if timer.phase == .running, !reduceMotion {
            TimelineView(.periodic(from: .now, by: 0.4)) { context in
                frameImage(at: context.date)
            }
        } else {
            frameImage(at: .now)
        }
    }

    private func frameImage(at date: Date) -> some View {
        let index = Int(date.timeIntervalSinceReferenceDate / 0.4) % frames.count
        return Image(nsImage: frames[index])
            .resizable()
            .interpolation(.high)
            .scaledToFit()
    }
}
