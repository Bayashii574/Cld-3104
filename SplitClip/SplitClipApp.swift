import SwiftUI

@main
struct SplitClipApp: App {
    init() {
        TempFiles.removeAll()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
