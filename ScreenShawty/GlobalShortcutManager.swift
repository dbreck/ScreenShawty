import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let shrinkClipboardImage = Self(
        "shrinkClipboardImage",
        default: .init(.s, modifiers: [.control, .option, .command])
    )
}

enum GlobalShortcutManager {

    static func register() {
        KeyboardShortcuts.onKeyUp(for: .shrinkClipboardImage) {
            ClipboardImageProcessor.shared.shrinkClipboardImage()
        }
    }
}
