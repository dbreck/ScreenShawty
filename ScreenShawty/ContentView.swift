import SwiftUI

struct ContentView: View {
    @Environment(ScreenshotManager.self) private var manager
    @Environment(ClipboardImageProcessor.self) private var processor

    var body: some View {
        locationMenu
        formatMenu

        Divider()

        Toggle("Window Shadow", isOn: Binding(
            get: { manager.shadowEnabled },
            set: { manager.setShadow($0) }
        ))

        Toggle("Floating Thumbnail", isOn: Binding(
            get: { manager.thumbnailEnabled },
            set: { manager.setThumbnail($0) }
        ))

        Toggle("Include Date", isOn: Binding(
            get: { manager.includeDateEnabled },
            set: { manager.setIncludeDate($0) }
        ))

        Divider()

        Button("Shrink Clipboard Image  \u{2303}\u{2325}\u{2318}S") {
            processor.shrinkClipboardImage()
        }

        Toggle("Auto-Shrink Clipboard", isOn: Binding(
            get: { processor.autoShrinkEnabled },
            set: { processor.autoShrinkEnabled = $0 }
        ))

        Button("Clipboard Settings\u{2026}") {
            SettingsWindowController.shared.show()
        }

        Divider()

        Toggle("Launch at Login", isOn: Binding(
            get: { LaunchAtLoginManager.isEnabled },
            set: { LaunchAtLoginManager.setEnabled($0) }
        ))

        Divider()

        Text("ScreenShawty v1.0.0")
            .foregroundStyle(.secondary)

        Button("Quit ScreenShawty") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    // MARK: - Location Submenu

    private var locationMenu: some View {
        Menu("Location: \(manager.displayLocation)") {
            Button(manager.isClipboardDestination ? "\u{2713} Clipboard" : "    Clipboard") {
                manager.setClipboardDestination()
            }

            Divider()

            let home = NSHomeDirectory()

            Button(locationLabel("Desktop", path: home + "/Desktop")) {
                manager.setLocation(home + "/Desktop")
            }
            Button(locationLabel("Downloads", path: home + "/Downloads")) {
                manager.setLocation(home + "/Downloads")
            }
            Button(locationLabel("Screenshots", path: home + "/Screenshots")) {
                manager.setLocation(home + "/Screenshots")
            }

            if let custom = manager.savedCustomLocation {
                let display = shortenPath(custom)
                Button(locationLabel(display, path: custom)) {
                    manager.setLocation(custom)
                }
            }

            Divider()

            Button("Choose Folder\u{2026}") {
                manager.chooseCustomLocation()
            }
        }
    }

    private func locationLabel(_ name: String, path: String) -> String {
        if !manager.isClipboardDestination && manager.currentLocation == path {
            return "\u{2713} " + name
        }
        return "    " + name
    }

    private func shortenPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + String(path.dropFirst(home.count))
        }
        return path
    }

    // MARK: - Format Submenu

    private var formatMenu: some View {
        Menu("Format: \(manager.currentFormat.rawValue)") {
            ForEach(ScreenshotManager.ImageFormat.allCases, id: \.self) { format in
                Button {
                    manager.setFormat(format)
                } label: {
                    if manager.currentFormat == format {
                        Text("\u{2713} \(format.rawValue)")
                    } else {
                        Text("    \(format.rawValue)")
                    }
                }
            }
        }
    }
}
