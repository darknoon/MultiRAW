import SwiftUI

@main
struct MultiRAWApp: App {
    var body: some Scene {
        WindowGroup {
            CaptureView()
                // Always use dark scheme as a camera
                .colorScheme(.dark)
                .statusBar(hidden: true)

        }
    }
}
