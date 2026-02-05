# ScreenShawty - macOS Menu Bar Screenshot Settings App

## Overview

A native macOS menu bar application using SwiftUI that allows quick toggling of screenshot defaults via `defaults write com.apple.screencapture` commands. The app lives exclusively in the menu bar (no dock icon) and provides instant access to common screenshot preferences.

---

## Technical Requirements

### Platform & Framework
- macOS 13+ (Ventura)
- SwiftUI with AppKit integration for menu bar (NSStatusItem)
- Swift 5.9+
- No external dependencies

### App Behavior
- Launch at login option (store in UserDefaults)
- No dock icon (set `LSUIElement = true` in Info.plist)
- Menu bar icon: SF Symbol `camera.viewfinder` or similar
- Runs `killall SystemUIServer` after any change to apply immediately

---

## Screenshot Settings to Control

### 1. Save Location
- **Read current:** `defaults read com.apple.screencapture location`
- **Options:**
  - Desktop (`~/Desktop`)
  - Downloads (`~/Downloads`)
  - Screenshots (`~/Screenshots`) — create folder if missing
  - Custom... (open folder picker, persist choice in UserDefaults)
- Show current location in menu (truncate long paths)

### 2. File Format
- **Read current:** `defaults read com.apple.screencapture type`
- **Options:** PNG, JPG, HEIC, PDF, TIFF, GIF
- Show checkmark next to active format

### 3. Window Shadow
- **Read current:** `defaults read com.apple.screencapture disable-shadow`
- **Toggle:** ON/OFF (inverted logic—`disable-shadow = true` means shadow OFF)
- Display current state clearly

### 4. Include Date in Filename
- **Read current:** `defaults read com.apple.screencapture include-date`
- **Toggle:** ON/OFF
- Default macOS behavior is ON

### 5. Show Floating Thumbnail
- **Read current:** `defaults read com.apple.screencapture show-thumbnail`
- **Toggle:** ON/OFF
- This is the preview that appears in corner after screenshot

### 6. Remember Last Selection
- **Read current:** `defaults read com.apple.screencapture target`
- **Toggle:** ON/OFF
- When ON, screenshot tool remembers last mode (area, window, etc.)

---

## UI Structure

```
[Camera Icon ▼]
─────────────────────────
📁 Location: ~/Desktop      ▸ [ Desktop ✓ ]
                              [ Downloads ]
                              [ Screenshots ]
                              [ Custom... ]
─────────────────────────
📄 Format: PNG              ▸ [ PNG ✓ ]
                              [ JPG ]
                              [ HEIC ]
                              [ PDF ]
─────────────────────────
☑️ Window Shadow: ON
☑️ Floating Thumbnail: ON
☑️ Include Date: ON
☑️ Remember Last Mode: ON
─────────────────────────
⚙️ Launch at Login: OFF
─────────────────────────
Quit ScreenShawty
```

---

## Implementation Details

### Reading Current Values

```swift
func readDefault(key: String) -> String? {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    task.arguments = ["read", "com.apple.screencapture", key]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    
    do {
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return task.terminationStatus == 0 ? output : nil
    } catch {
        return nil
    }
}
```

### Writing Values

```swift
func writeDefault(key: String, value: String, type: String? = nil) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    
    var args = ["write", "com.apple.screencapture", key]
    if let type = type {
        args.append("-\(type)")
    }
    args.append(value)
    task.arguments = args
    
    try? task.run()
    task.waitUntilExit()
    
    // Apply changes immediately
    restartSystemUIServer()
}

func restartSystemUIServer() {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
    task.arguments = ["SystemUIServer"]
    try? task.run()
}
```

### Error Handling
- If a key doesn't exist, assume macOS default
- Handle permission errors gracefully
- If SystemUIServer kill fails, show alert but don't crash

### State Management
- Use `@Observable` class (macOS 14+) or `ObservableObject` (macOS 13) to track all current settings
- Refresh state when menu opens (user might change via terminal)
- Debounce rapid toggles (300ms) before running killall

---

## File Structure

```
ScreenShawty/
├── ScreenShawty.xcodeproj/
├── ScreenShawty/
│   ├── ScreenShawtyApp.swift        # App entry, MenuBarExtra setup
│   ├── ContentView.swift              # Main menu structure
│   ├── ScreenshotManager.swift        # Read/write defaults, shell commands
│   ├── LaunchAtLoginManager.swift     # SMAppService handling
│   ├── Assets.xcassets/
│   └── Info.plist                     # LSUIElement = true
└── README.md
```

---

## Launch at Login

Use `SMAppService` (macOS 13+):

```swift
import ServiceManagement

class LaunchAtLoginManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
    
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }
}
```

---

## Key Implementation Notes

### MenuBarExtra (SwiftUI native, macOS 13+)

Use SwiftUI's native `MenuBarExtra` instead of manual NSStatusItem:

```swift
@main
struct ScreenShawtyApp: App {
    @StateObject private var manager = ScreenshotManager()
    
    var body: some Scene {
        MenuBarExtra("ScreenShawty", systemImage: "camera.viewfinder") {
            ContentView()
                .environmentObject(manager)
        }
        .menuBarExtraStyle(.menu)
    }
}
```

### Info.plist Requirements

Add to Info.plist:
```xml
<key>LSUIElement</key>
<true/>
```

This hides the app from the Dock.

### Handling Submenus

For Location and Format submenus, use SwiftUI `Menu`:

```swift
Menu {
    ForEach(Format.allCases, id: \.self) { format in
        Button {
            manager.setFormat(format)
        } label: {
            if manager.currentFormat == format {
                Label(format.rawValue, systemImage: "checkmark")
            } else {
                Text(format.rawValue)
            }
        }
    }
} label: {
    Label("Format: \(manager.currentFormat.rawValue)", systemImage: "doc")
}
```

---

## Polish Details

- Use dividers (`Divider()`) between sections
- Show version number in menu footer (v1.0.0)
- App name: "ScreenShawty"
- Bundle identifier: `com.clearph.screenshawty`

---

## Build & Distribution

### Building
1. Open `ScreenShawty.xcodeproj` in Xcode
2. Select "My Mac" as the run destination
3. Build with ⌘B or run with ⌘R
4. Archive for distribution: Product → Archive

### Installation
1. Build the app
2. Copy `ScreenShawty.app` to `/Applications`
3. Launch the app
4. Optionally enable "Launch at Login" from the menu

---

## Clipboard Image Processing

### Overview
In addition to managing screenshot defaults, the app can process images on the clipboard—resizing and compressing them before pasting. This replaces the "Shrink Clipboard Image" Shortcut with more control.

### Features

#### 1. Shrink Clipboard Image
- **Trigger:** Menu item "Shrink Clipboard Image" + global keyboard shortcut (user-configurable, default: ⌃⌥⌘S)
- **Behavior:** 
  1. Read image from clipboard
  2. Resize to max width (preserving aspect ratio)
  3. Compress to target quality
  4. Replace clipboard contents with processed image
  5. Show brief notification: "Image shrunk: 1200×800 → 1000×667 (85% smaller)"

#### 2. Configurable Settings (stored in UserDefaults)

| Setting | Default | Range/Options |
|---------|---------|---------------|
| Max Width | 1000px | 400–2000px (slider) |
| Max Height | Auto (preserve ratio) | Auto / Custom |
| Output Format | Original | Original, PNG, JPEG, HEIC |
| JPEG/HEIC Quality | 80% | 10–100% (slider) |
| PNG Compression | Default | Default, Maximum |
| Strip Metadata | ON | ON/OFF (removes EXIF, etc.) |

#### 3. Settings UI

Add a "Clipboard Settings..." menu item that opens a small SwiftUI settings window:

```
┌─────────────────────────────────────────┐
│  Clipboard Image Settings               │
├─────────────────────────────────────────┤
│  Max Width:  [1000] px                  │
│  ○ Auto height  ○ Max height: [___] px  │
│                                         │
│  Output Format: [Original ▼]            │
│                                         │
│  Quality: ────●──────── 80%             │
│           (for JPEG/HEIC output)        │
│                                         │
│  ☑ Strip metadata (EXIF, GPS, etc.)     │
│                                         │
│  Keyboard Shortcut: [⌃⌥⌘S] [Record]     │
├─────────────────────────────────────────┤
│                          [Done]         │
└─────────────────────────────────────────┘
```

### Implementation Details

#### Reading Clipboard Image

```swift
func getClipboardImage() -> NSImage? {
    let pasteboard = NSPasteboard.general
    guard let image = NSImage(pasteboard: pasteboard) else { return nil }
    return image
}
```

#### Resizing Image

```swift
func resizeImage(_ image: NSImage, maxWidth: CGFloat, maxHeight: CGFloat? = nil) -> NSImage {
    let originalSize = image.size
    var newSize = originalSize
    
    // Scale to fit max width
    if originalSize.width > maxWidth {
        let ratio = maxWidth / originalSize.width
        newSize = CGSize(width: maxWidth, height: originalSize.height * ratio)
    }
    
    // Further scale if exceeds max height
    if let maxH = maxHeight, newSize.height > maxH {
        let ratio = maxH / newSize.height
        newSize = CGSize(width: newSize.width * ratio, height: maxH)
    }
    
    let newImage = NSImage(size: newSize)
    newImage.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: newSize),
               from: NSRect(origin: .zero, size: originalSize),
               operation: .copy,
               fraction: 1.0)
    newImage.unlockFocus()
    
    return newImage
}
```

#### Compressing & Converting

```swift
enum OutputFormat: String, CaseIterable {
    case original = "Original"
    case png = "PNG"
    case jpeg = "JPEG"
    case heic = "HEIC"
}

func compressImage(_ image: NSImage, format: OutputFormat, quality: CGFloat) -> Data? {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
    
    switch format {
    case .original, .png:
        return bitmap.representation(using: .png, properties: [:])
    case .jpeg:
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
    case .heic:
        // Requires macOS 10.13+
        return bitmap.heicData(compressionQuality: quality)
    }
}

extension NSBitmapImageRep {
    func heicData(compressionQuality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, "public.heic" as CFString, 1, nil),
              let cgImage = self.cgImage else { return nil }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)
        CGImageDestinationFinalize(dest)
        
        return data as Data
    }
}
```

#### Writing Back to Clipboard

```swift
func setClipboardImage(_ data: Data, format: OutputFormat) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    
    let type: NSPasteboard.PasteboardType = {
        switch format {
        case .png, .original: return .png
        case .jpeg: return .jpeg  // Note: may need custom UTI
        case .heic: return NSPasteboard.PasteboardType("public.heic")
        }
    }()
    
    pasteboard.setData(data, forType: type)
    
    // Also set as generic image for broader compatibility
    if let image = NSImage(data: data) {
        pasteboard.writeObjects([image])
    }
}
```

#### Global Keyboard Shortcut

Use `MASShortcut` (popular library) or implement with `CGEvent` tap. For simplicity, can use `NSEvent.addGlobalMonitorForEvents`:

```swift
// Note: Requires Accessibility permissions
func registerGlobalShortcut() {
    NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
        // Check for ⌃⌥⌘S
        if event.modifierFlags.contains([.control, .option, .command]) &&
           event.charactersIgnoringModifiers == "s" {
            self.shrinkClipboardImage()
        }
    }
}
```

Alternatively, use `KeyboardShortcuts` Swift package for cleaner implementation.

#### User Notification

```swift
func showNotification(originalSize: CGSize, newSize: CGSize, originalBytes: Int, newBytes: Int) {
    let notification = NSUserNotification()
    notification.title = "Image Shrunk"
    
    let reduction = 100 - Int((Double(newBytes) / Double(originalBytes)) * 100)
    notification.informativeText = "\(Int(originalSize.width))×\(Int(originalSize.height)) → \(Int(newSize.width))×\(Int(newSize.height)) (\(reduction)% smaller)"
    
    NSUserNotificationCenter.default.deliver(notification)
}
```

Or use the newer `UserNotifications` framework for macOS 11+.

### Updated UI Structure

```
[Camera Icon ▼]
─────────────────────────────────────────
📁 Location: ~/Desktop              ▸
📄 Format: PNG                      ▸
─────────────────────────────────────────
☑️ Window Shadow: ON
☑️ Floating Thumbnail: ON
☑️ Include Date: ON
☑️ Remember Last Mode: ON
─────────────────────────────────────────
✂️ Shrink Clipboard Image      ⌃⌥⌘S
⚙️ Clipboard Settings...
─────────────────────────────────────────
🚀 Launch at Login: OFF
─────────────────────────────────────────
Quit ScreenShawty
```

### Updated File Structure

```
ScreenShawty/
├── ScreenShawty.xcodeproj/
├── ScreenShawty/
│   ├── ScreenShawtyApp.swift
│   ├── ContentView.swift              # Main menu
│   ├── ClipboardSettingsView.swift    # Settings window
│   ├── ScreenshotManager.swift        # Screenshot defaults
│   ├── ClipboardImageProcessor.swift  # Resize/compress logic
│   ├── GlobalShortcutManager.swift    # Keyboard shortcut handling
│   ├── NotificationManager.swift      # User notifications
│   ├── LaunchAtLoginManager.swift
│   ├── Assets.xcassets/
│   └── Info.plist
└── README.md
```

### Additional Info.plist Requirements

For global keyboard shortcuts (Accessibility):
```xml
<key>NSAppleEventsUsageDescription</key>
<string>ScreenShawty needs accessibility access to register global keyboard shortcuts.</string>
```

For notifications:
```xml
<key>NSUserNotificationAlertStyle</key>
<string>banner</string>
```

---

## Testing Checklist

After building, verify:
- [ ] App appears only in menu bar, not dock
- [ ] All toggles read current state correctly on launch
- [ ] Changing location immediately affects next screenshot (test with ⌘⇧3)
- [ ] Format change persists after app quit/relaunch
- [ ] Shadow toggle works (test with ⌘⇧4, then Space, click window)
- [ ] Floating thumbnail toggle works
- [ ] Launch at login actually works after logout/login
- [ ] Custom location folder picker works
- [ ] Quit button closes app completely

### Clipboard Processing Tests
- [ ] "Shrink Clipboard Image" works with PNG on clipboard
- [ ] Works with JPEG on clipboard
- [ ] Shows notification with size reduction stats
- [ ] Respects max width setting
- [ ] Quality slider affects output file size
- [ ] Global shortcut triggers processing
- [ ] Gracefully handles non-image clipboard content (shows alert)
- [ ] Settings window opens and saves preferences
- [ ] "Strip metadata" actually removes EXIF data

---

## Default macOS Values Reference

| Setting | Default Value | defaults key |
|---------|---------------|--------------|
| Location | ~/Desktop | `location` |
| Format | png | `type` |
| Shadow | enabled | `disable-shadow` (false) |
| Thumbnail | enabled | `show-thumbnail` (true) |
| Include Date | enabled | `include-date` (true) |
| Remember Target | disabled | `target` |
