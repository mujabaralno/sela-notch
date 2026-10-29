import SwiftUI

@main
struct SelaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 460, height: 300)
    }
}
