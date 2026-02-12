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
- None currently known.

## Known macOS Tahoe (26) Behaviors
- `killall SystemUIServer` is a no-op for screenshot settings — screenshots are now handled by `screencaptureui.app`, not SystemUIServer. The `defaults write com.apple.screencapture` commands still work; cfprefsd syncs them automatically.
- The floating thumbnail feature can interfere with screenshot saving (especially PDF format). Disabling `show-thumbnail` works around it.

## Website
- **URL:** https://screenshawty.app
- **Hosting:** GitHub Pages (from `docs/` on `main` branch)
- **Domain registrar:** Vercel (DNS managed there)
- **DNS:** 4x A records → GitHub Pages IPs, `www` CNAME → `dbreck.github.io`
- **Download buttons** link directly to DMG: `https://github.com/dbreck/ScreenShawty/releases/download/v1.0.0/ScreenShawty-1.0.0.dmg` — update these URLs when releasing new versions

## Next Steps
- [x] Create GitHub repo
- [x] Code signing with Developer ID for distribution outside App Store
- [x] App icon design
- [x] Fix screenshot save location bug (was not a bug — location works, was untested)
- [x] Remove `killall SystemUIServer` (no-op on macOS 14+; cfprefsd syncs defaults automatically)
- [x] README screenshots
- [x] Notarization for direct distribution (accepted Feb 5, 2026; stapled Feb 11)
- [x] GitHub Release with notarized DMG — https://github.com/dbreck/ScreenShawty/releases/tag/v1.0.0
- [x] Landing page + custom domain (screenshawty.app)
- [ ] App Store submission (will need App Sandbox — requires reworking Process calls to use a privileged helper or XPC service, since sandboxed apps can't run arbitrary shell commands)
