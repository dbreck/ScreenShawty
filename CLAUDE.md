# ScreenShawty

## Skills to Engage
When starting a new session on this project, use:
- **swiftui-developer** — for any SwiftUI view or state management work
- **macos-swiftui** — for macOS-specific patterns (MenuBarExtra, NSWindow, etc.)

## About
macOS menu bar utility for controlling screenshot defaults and shrinking clipboard images. No dock icon — lives entirely in the menu bar.

## Tech Stack
- **Platform:** macOS 14.0+ (Sonoma)
- **Framework:** SwiftUI with MenuBarExtra (.menu style)
- **Language:** Swift 5.9+
- **External Dependency:** [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 2.x (via SPM)
- **Bundle ID:** `com.clearph.screenshawty`
- **Repo:** [github.com/dbreck/ScreenShawty](https://github.com/dbreck/ScreenShawty) (public)

## Project Structure
```
ScreenShawty/
├── ScreenShawty.xcodeproj/
├── ScreenShawty/
│   ├── ScreenShawtyApp.swift          # @main entry, MenuBarExtra setup, shortcut registration
│   ├── ContentView.swift                # Main menu: location, format, toggles, clipboard actions
│   ├── ScreenshotManager.swift          # Reads/writes com.apple.screencapture defaults via Process
│   ├── ClipboardImageProcessor.swift    # Singleton — resize, compress, format convert, auto-shrink monitor
│   ├── ClipboardSettingsView.swift      # Settings window (Form) + SettingsWindowController (NSWindow)
│   ├── GlobalShortcutManager.swift      # KeyboardShortcuts extension, registers ⌃⌥⌘S
│   ├── NotificationManager.swift        # UNUserNotificationCenter wrapper
│   ├── LaunchAtLoginManager.swift       # SMAppService register/unregister
│   ├── Info.plist                       # LSUIElement = true (no dock icon)
│   ├── ScreenShawty.entitlements
│   └── Assets.xcassets/                 # App icon + accent color
├── scripts/
│   └── build-release.sh                 # Automated archive → sign → notarize → DMG pipeline
├── ExportOptions.plist                  # Xcode archive export config (developer-id method)
├── assets/                              # README images (icon, screenshots)
├── README.md
├── SPEC.md
└── CLAUDE.md
```

## Architecture Notes
- **ScreenshotManager** is `@Observable`, injected via `.environment()`. Reads/writes `com.apple.screencapture` defaults using `/usr/bin/defaults` Process calls. Debounces `killall SystemUIServer` by 300ms.
- **ClipboardImageProcessor** is `@Observable` with a `.shared` singleton. Settings (maxWidth, quality, format, etc.) persist to UserDefaults via `didSet`. The global shortcut calls `ClipboardImageProcessor.shared.shrinkClipboardImage()`. Auto-shrink monitors clipboard via `changeCount` polling on a 1s timer.
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
- `clipAutoShrink` — auto-shrink clipboard toggle

## Current Version
1.0.0

## Release / Distribution

### Code Signing
- **Identity:** Developer ID Application: Daniel Breckenridge (Team: `7DMXWUCLVN`)
- **Hardened Runtime:** Enabled (no special entitlements needed)
- Release config uses `CODE_SIGN_STYLE = Manual` (required — Automatic conflicts with Developer ID)

### Notarization Credentials
Already stored in keychain as profile `"ScreenShawty"` (Apple ID: dbreck@gmail.com).

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

## Open Bugs
- **Screenshots not saving to ~/Screenshots** — Location is set correctly in `com.apple.screencapture` defaults, SystemUIServer was restarted, but screenshots don't appear in the folder. Needs investigation. Possibly a macOS permissions issue or the `location` default isn't being respected. Check if the issue reproduces with other folders (Desktop, Downloads).

## In Progress / Next Session TODO
1. **Notarization stuck** — Apple's notarization service was unresponsive all day (Feb 5, 2026). 4 submissions all stuck "In Progress." Latest submission ID: `179c0a52-2bf5-4508-b2e8-495f339b78d6`. Next session: check `xcrun notarytool history --keychain-profile "ScreenShawty"` — if any completed, staple and create GitHub release. If still stuck, resubmit.
2. **Fix screenshot location bug** — Investigate why screenshots aren't saving to the selected folder.
3. **README screenshots** — Need `assets/screenshot-menu.png` and `assets/screenshot-settings.png`. Take screenshots of the menu and clipboard settings window, save to `assets/`.
4. **Commit & push** — README, icon assets, and icon-concept.svg are uncommitted.

## Next Steps
- [x] Create GitHub repo
- [x] Code signing with Developer ID for distribution outside App Store
- [x] App icon design
- [ ] Notarization for direct distribution (blocked by Apple service — recheck next session)
- [ ] GitHub Release with notarized DMG
- [ ] README screenshots
- [ ] Fix screenshot save location bug
- [ ] App Store submission (will need App Sandbox — requires reworking Process calls to use a privileged helper or XPC service, since sandboxed apps can't run arbitrary shell commands)
