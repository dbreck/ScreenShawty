# ScreenShawty

## About
macOS menu bar utility for controlling screenshot defaults and shrinking clipboard images. No dock icon — lives entirely in the menu bar.

## Tech Stack
- **Platform:** macOS 14.0+ (Sonoma)
- **Framework:** SwiftUI with MenuBarExtra (.menu style)
- **Language:** Swift 5.9+
- **External Dependency:** [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 2.x (via SPM)
- **Bundle ID:** `com.clearph.screenshawty`

## Project Structure
```
ScreenShawty/
├── ScreenShawty.xcodeproj/
├── ScreenShawty/
│   ├── ScreenShawtyApp.swift          # @main entry, MenuBarExtra setup, shortcut registration
│   ├── ContentView.swift                # Main menu: location, format, toggles, clipboard actions
│   ├── ScreenshotManager.swift          # Reads/writes com.apple.screencapture defaults via Process
│   ├── ClipboardImageProcessor.swift    # Singleton — resize, compress, format convert clipboard images
│   ├── ClipboardSettingsView.swift      # Settings window (Form) + SettingsWindowController (NSWindow)
│   ├── GlobalShortcutManager.swift      # KeyboardShortcuts extension, registers ⌃⌥⌘S
│   ├── NotificationManager.swift        # UNUserNotificationCenter wrapper
│   ├── LaunchAtLoginManager.swift       # SMAppService register/unregister
│   ├── Info.plist                       # LSUIElement = true (no dock icon)
│   ├── ScreenShawty.entitlements
│   └── Assets.xcassets/
└── SPEC.md
```

## Architecture Notes
- **ScreenshotManager** is `@Observable`, injected via `.environment()`. Reads/writes `com.apple.screencapture` defaults using `/usr/bin/defaults` Process calls. Debounces `killall SystemUIServer` by 300ms.
- **ClipboardImageProcessor** is `@Observable` with a `.shared` singleton. Settings (maxWidth, quality, format, etc.) persist to UserDefaults via `didSet`. The global shortcut calls `ClipboardImageProcessor.shared.shrinkClipboardImage()`.
- **Settings window** uses `SettingsWindowController` (manages an NSWindow with NSHostingView) rather than a SwiftUI Window scene — more reliable for menu bar apps.
- **Location: Clipboard** sets `defaults write com.apple.screencapture target clipboard`. Selecting any file location clears the `target` key.

## Build
```bash
cd /Users/dannybreckenridge/Applications/ScreenShawty
xcodebuild -project ScreenShawty.xcodeproj -scheme ScreenShawty -configuration Debug -destination 'platform=macOS' build
```

Or open `ScreenShawty.xcodeproj` in Xcode and press ⌘R.

## Key Defaults Used
| Setting | Key | Values |
|---------|-----|--------|
| Save location | `location` | File path |
| Destination | `target` | `clipboard` or absent |
| Format | `type` | `png`, `jpg`, `heic`, `pdf`, `tiff`, `gif` |
| Shadow | `disable-shadow` | `true`/`false` (inverted) |
| Thumbnail | `show-thumbnail` | `true`/`false` |
| Include date | `include-date` | `true`/`false` |

## UserDefaults Keys (app preferences)
- `customScreenshotLocation` — last custom folder path
- `clipMaxWidth`, `clipMaxHeight`, `clipUseCustomHeight` — resize settings
- `clipOutputFormat`, `clipQuality`, `clipStripMetadata` — compression settings

## Current Version
1.0.0

## Next Steps
- [ ] Create GitHub repo
- [ ] Code signing with Developer ID for distribution outside App Store
- [ ] App Store submission (will need App Sandbox — requires reworking Process calls to use a privileged helper or XPC service, since sandboxed apps can't run arbitrary shell commands)
- [ ] App icon design
- [ ] Notarization for direct distribution (.dmg / .zip)
