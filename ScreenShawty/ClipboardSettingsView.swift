import SwiftUI
import KeyboardShortcuts

struct ClipboardSettingsView: View {
    @Environment(ClipboardImageProcessor.self) private var processor

    var body: some View {
        @Bindable var processor = processor

        Form {
            Section("Resize") {
                HStack {
                    Text("Max Width:")
                    Slider(value: $processor.maxWidth, in: 400...2000, step: 50)
                    Text("\(Int(processor.maxWidth)) px")
                        .monospacedDigit()
                        .frame(width: 60, alignment: .trailing)
                }

                Picker("Height:", selection: $processor.useCustomHeight) {
                    Text("Auto (preserve ratio)").tag(false)
                    Text("Custom max height").tag(true)
                }

                if processor.useCustomHeight {
                    HStack {
                        Text("Max Height:")
                        Slider(value: $processor.maxHeight, in: 400...2000, step: 50)
                        Text("\(Int(processor.maxHeight)) px")
                            .monospacedDigit()
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }

            Section("Output") {
                Picker("Format:", selection: $processor.outputFormat) {
                    ForEach(ClipboardImageProcessor.OutputFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }

                if processor.outputFormat == .jpeg || processor.outputFormat == .heic {
                    HStack {
                        Text("Quality:")
                        Slider(value: $processor.quality, in: 0.1...1.0, step: 0.05)
                        Text("\(Int(processor.quality * 100))%")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }

            Section("Metadata") {
                Toggle("Strip metadata (EXIF, GPS, etc.)", isOn: $processor.stripMetadata)
            }

            Section("Keyboard Shortcut") {
                KeyboardShortcuts.Recorder("Shortcut:", name: .shrinkClipboardImage)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 380)
    }
}

// MARK: - Window Controller

final class SettingsWindowController: NSObject {

    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = ClipboardSettingsView()
            .environment(ClipboardImageProcessor.shared)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clipboard Image Settings"
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
