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

## Release / Distribution

### Code Signing
- **Identity:** Developer ID Application (Team: `7DMXWUCLVN`)
- **Hardened Runtime:** Enabled (no special entitlements needed)
- Release config in `project.pbxproj` has `CODE_SIGN_IDENTITY` and `DEVELOPMENT_TEAM` set

### One-time Setup: Notarization Credentials
Store your App Store Connect credentials in the keychain so the build script can notarize:
```bash
xcrun notarytool store-credentials "ScreenShawty" \
    --apple-id YOUR_APPLE_ID \
    --team-id 7DMXWUCLVN \
    --password APP_SPECIFIC_PASSWORD
```
Generate the app-specific password at [appleid.apple.com](https://appleid.apple.com/account/manage) → Sign-In and Security → App-Specific Passwords.

### Build a Release
```bash
./scripts/build-release.sh
```
This automates: archive → export signed app → notarize → staple → DMG → notarize DMG → verify.

Output: `build/ScreenShawty-{version}.dmg`

### Create a GitHub Release
```bash
gh release create v1.0.0 build/ScreenShawty-1.0.0.dmg \
    --title "ScreenShawty v1.0.0" \
    --notes "Initial release"
```

### Key Files
| File | Purpose |
|------|---------|
| `scripts/build-release.sh` | Automated build → sign → notarize → DMG pipeline |
| `ExportOptions.plist` | Xcode archive export config (developer-id method) |

## Next Steps
- [ ] Create GitHub repo
- [x] Code signing with Developer ID for distribution outside App Store
- [x] Notarization for direct distribution (.dmg / .zip)
- [ ] App Store submission (will need App Sandbox — requires reworking Process calls to use a privileged helper or XPC service, since sandboxed apps can't run arbitrary shell commands)
- [ ] App icon design
