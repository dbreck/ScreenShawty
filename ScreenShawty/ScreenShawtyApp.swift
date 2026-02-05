import SwiftUI

@main
struct ScreenShawtyApp: App {
    @State private var screenshotManager = ScreenshotManager()

    init() {
        GlobalShortcutManager.register()
    }

    var body: some Scene {
        MenuBarExtra("ScreenShawty", systemImage: "camera.viewfinder") {
            ContentView()
                .environment(screenshotManager)
                .environment(ClipboardImageProcessor.shared)
        }
        .menuBarExtraStyle(.menu)
    }
}
