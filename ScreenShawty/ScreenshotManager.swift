import AppKit

@Observable
final class ScreenshotManager {

    enum ImageFormat: String, CaseIterable {
        case png = "PNG"
        case jpg = "JPG"
        case heic = "HEIC"
        case pdf = "PDF"
        case tiff = "TIFF"
        case gif = "GIF"

        var defaultsValue: String { rawValue.lowercased() }
    }

    private(set) var currentLocation: String = ""
    private(set) var currentFormat: ImageFormat = .png
    private(set) var shadowEnabled: Bool = true
    private(set) var thumbnailEnabled: Bool = true
    private(set) var includeDateEnabled: Bool = true
    private(set) var isClipboardDestination: Bool = false

    var displayLocation: String {
        if isClipboardDestination { return "Clipboard" }
        let home = NSHomeDirectory()
        if currentLocation.hasPrefix(home) {
            return "~" + String(currentLocation.dropFirst(home.count))
        }
        let components = currentLocation.components(separatedBy: "/").filter { !$0.isEmpty }
        if components.count > 3 {
            return ".../" + components.suffix(2).joined(separator: "/")
        }
        return currentLocation
    }

    var savedCustomLocation: String? {
        UserDefaults.standard.string(forKey: "customScreenshotLocation")
    }

    private var restartTask: Task<Void, Never>?

    init() {
        refreshState()
    }

    func refreshState() {
        if let loc = readDefault(key: "location") {
            currentLocation = loc
        } else {
            currentLocation = NSHomeDirectory() + "/Desktop"
        }

        if let typeStr = readDefault(key: "type"),
           let fmt = ImageFormat.allCases.first(where: { $0.defaultsValue == typeStr.lowercased() }) {
            currentFormat = fmt
        } else {
            currentFormat = .png
        }

        if let val = readDefault(key: "disable-shadow") {
            shadowEnabled = (val != "1" && val.lowercased() != "true")
        } else {
            shadowEnabled = true
        }

        if let val = readDefault(key: "show-thumbnail") {
            thumbnailEnabled = (val == "1" || val.lowercased() == "true")
        } else {
            thumbnailEnabled = true
        }

        if let val = readDefault(key: "include-date") {
            includeDateEnabled = (val == "1" || val.lowercased() == "true")
        } else {
            includeDateEnabled = true
        }

        if let target = readDefault(key: "target") {
            isClipboardDestination = target.lowercased() == "clipboard"
        } else {
            isClipboardDestination = false
        }
    }

    // MARK: - Setters

    func setLocation(_ path: String) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            try? fm.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
        // Switching to a file destination — clear clipboard target
        deleteDefault(key: "target")
        isClipboardDestination = false

        writeDefault(key: "location", value: path)
        currentLocation = path
        let home = NSHomeDirectory()
        if path != home + "/Desktop" && path != home + "/Downloads" && path != home + "/Screenshots" {
            UserDefaults.standard.set(path, forKey: "customScreenshotLocation")
        }
        debouncedRestart()
    }

    func setClipboardDestination() {
        writeDefault(key: "target", value: "clipboard")
        isClipboardDestination = true
        debouncedRestart()
    }

    func setFormat(_ format: ImageFormat) {
        writeDefault(key: "type", value: format.defaultsValue)
        currentFormat = format
        debouncedRestart()
    }

    func setShadow(_ enabled: Bool) {
        writeDefault(key: "disable-shadow", value: enabled ? "0" : "1", type: "bool")
        shadowEnabled = enabled
        debouncedRestart()
    }

    func setThumbnail(_ enabled: Bool) {
        writeDefault(key: "show-thumbnail", value: enabled ? "1" : "0", type: "bool")
        thumbnailEnabled = enabled
        debouncedRestart()
    }

    func setIncludeDate(_ enabled: Bool) {
        writeDefault(key: "include-date", value: enabled ? "1" : "0", type: "bool")
        includeDateEnabled = enabled
        debouncedRestart()
    }

    func chooseCustomLocation() {
        DispatchQueue.main.async { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Choose"
            panel.message = "Choose a folder for screenshots"
            if panel.runModal() == .OK, let url = panel.url {
                self?.setLocation(url.path)
            }
        }
    }

    // MARK: - Shell Commands

    private func readDefault(key: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", "com.apple.screencapture", key]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return task.terminationStatus == 0 ? output : nil
        } catch {
            return nil
        }
    }

    private func writeDefault(key: String, value: String, type: String? = nil) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        var args = ["write", "com.apple.screencapture", key]
        if let type { args.append("-\(type)") }
        args.append(value)
        task.arguments = args
        try? task.run()
        task.waitUntilExit()
    }

    private func deleteDefault(key: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["delete", "com.apple.screencapture", key]
        try? task.run()
        task.waitUntilExit()
    }

    private func debouncedRestart() {
        restartTask?.cancel()
        restartTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            restartSystemUIServer()
        }
    }

    private func restartSystemUIServer() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["SystemUIServer"]
        try? task.run()
    }
}
