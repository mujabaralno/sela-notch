import AppKit
import SwiftUI

@MainActor
final class PetSpriteSheet {
    static let shared = PetSpriteSheet()

    private(set) var displayName = "Pet"
    private(set) var frames: [NSImage] = []

    private struct Definition: Decodable {
        let displayName: String
        let spritesheetPath: String
    }

    private static let frameSize = CGSize(width: 192, height: 208)
    private static let animationRow = 0
    private static let animationColumns = [3, 4, 5]

    private init() {
        guard let definitionURL = Bundle.main.url(forResource: "pet", withExtension: "json"),
              let definitionData = try? Data(contentsOf: definitionURL),
              let definition = try? JSONDecoder().decode(Definition.self, from: definitionData),
              let sheetURL = Bundle.main.url(forResource: definition.spritesheetPath, withExtension: nil),
              let sheet = NSImage(contentsOf: sheetURL),
              let sheetImage = sheet.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }

        displayName = definition.displayName

        let rows = Int(CGFloat(sheetImage.height) / Self.frameSize.height)
        let columns = Int(CGFloat(sheetImage.width) / Self.frameSize.width)
        guard Self.animationRow < rows else { return }

        frames = Self.animationColumns.compactMap { column in
            guard column < columns else { return nil }
            let rect = CGRect(
                x: CGFloat(column) * Self.frameSize.width,
                y: CGFloat(Self.animationRow) * Self.frameSize.height,
                width: Self.frameSize.width,
                height: Self.frameSize.height
            )
            return sheetImage.cropping(to: rect).map { NSImage(cgImage: $0, size: Self.frameSize) }
        }
    }
}
