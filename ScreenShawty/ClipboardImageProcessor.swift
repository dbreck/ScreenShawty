import AppKit
import ImageIO

@Observable
final class ClipboardImageProcessor {

    static let shared = ClipboardImageProcessor()

    enum OutputFormat: String, CaseIterable {
        case original = "Original"
        case png = "PNG"
        case jpeg = "JPEG"
        case heic = "HEIC"
    }

    var maxWidth: Double = 1000 {
        didSet { UserDefaults.standard.set(maxWidth, forKey: "clipMaxWidth") }
    }

    var useCustomHeight: Bool = false {
        didSet { UserDefaults.standard.set(useCustomHeight, forKey: "clipUseCustomHeight") }
    }

    var maxHeight: Double = 1000 {
        didSet { UserDefaults.standard.set(maxHeight, forKey: "clipMaxHeight") }
    }

    var outputFormat: OutputFormat = .original {
        didSet { UserDefaults.standard.set(outputFormat.rawValue, forKey: "clipOutputFormat") }
    }

    var quality: Double = 0.8 {
        didSet { UserDefaults.standard.set(quality, forKey: "clipQuality") }
    }

    var stripMetadata: Bool = true {
        didSet { UserDefaults.standard.set(stripMetadata, forKey: "clipStripMetadata") }
    }

    var autoShrinkEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(autoShrinkEnabled, forKey: "clipAutoShrink")
            if autoShrinkEnabled {
                startClipboardMonitor()
            } else {
                stopClipboardMonitor()
            }
        }
    }

    private var clipboardTimer: Timer?
    private var lastChangeCount: Int = 0

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "clipMaxWidth") != nil {
            maxWidth = defaults.double(forKey: "clipMaxWidth")
        }
        if defaults.object(forKey: "clipUseCustomHeight") != nil {
            useCustomHeight = defaults.bool(forKey: "clipUseCustomHeight")
        }
        if defaults.object(forKey: "clipMaxHeight") != nil {
            maxHeight = defaults.double(forKey: "clipMaxHeight")
        }
        if let fmt = defaults.string(forKey: "clipOutputFormat"),
           let f = OutputFormat(rawValue: fmt) {
            outputFormat = f
        }
        if defaults.object(forKey: "clipQuality") != nil {
            quality = defaults.double(forKey: "clipQuality")
        }
        if defaults.object(forKey: "clipStripMetadata") != nil {
            stripMetadata = defaults.bool(forKey: "clipStripMetadata")
        }
        if defaults.object(forKey: "clipAutoShrink") != nil {
            autoShrinkEnabled = defaults.bool(forKey: "clipAutoShrink")
        }
        lastChangeCount = NSPasteboard.general.changeCount
        if autoShrinkEnabled {
            startClipboardMonitor()
        }
    }

    // MARK: - Main Action

    func shrinkClipboardImage() {
        let pasteboard = NSPasteboard.general

        guard let image = NSImage(pasteboard: pasteboard) else {
            NotificationManager.shared.show(
                title: "No Image Found",
                body: "There's no image on the clipboard to shrink."
            )
            return
        }

        let originalPixelSize = pixelSize(of: image)
        let originalBytes = estimateOriginalBytes(from: pasteboard, image: image)

        let customH: CGFloat? = useCustomHeight ? CGFloat(maxHeight) : nil
        let resized = resizeImage(image, maxWidth: CGFloat(maxWidth), maxHeight: customH)
        let newPixelSize = pixelSize(of: resized)

        let format = resolveFormat()
        guard let outputData = compressImage(resized, format: format) else {
            NotificationManager.shared.show(
                title: "Processing Failed",
                body: "Failed to compress the clipboard image."
            )
            return
        }

        writeToClipboard(outputData, format: format)

        let reduction = originalBytes > 0
            ? max(0, Int((1.0 - Double(outputData.count) / Double(originalBytes)) * 100))
            : 0
        NotificationManager.shared.show(
            title: "Image Shrunk",
            body: "\(Int(originalPixelSize.width))\u{00D7}\(Int(originalPixelSize.height)) \u{2192} \(Int(newPixelSize.width))\u{00D7}\(Int(newPixelSize.height)) (\(reduction)% smaller)"
        )
    }

    // MARK: - Helpers

    private func pixelSize(of image: NSImage) -> CGSize {
        guard let rep = image.representations.first else { return image.size }
        return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }

    private func estimateOriginalBytes(from pasteboard: NSPasteboard, image: NSImage) -> Int {
        if let data = pasteboard.data(forType: .png) { return data.count }
        if let data = pasteboard.data(forType: .tiff) { return data.count }
        return image.tiffRepresentation?.count ?? 0
    }

    private func resolveFormat() -> OutputFormat {
        if outputFormat != .original { return outputFormat }
        let types = NSPasteboard.general.types ?? []
        if types.contains(.png) { return .png }
        if types.contains(NSPasteboard.PasteboardType("public.jpeg")) { return .jpeg }
        if types.contains(NSPasteboard.PasteboardType("public.heic")) { return .heic }
        return .png
    }

    // MARK: - Resize

    private func resizeImage(_ image: NSImage, maxWidth: CGFloat, maxHeight: CGFloat? = nil) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }

        let origW = CGFloat(cgImage.width)
        let origH = CGFloat(cgImage.height)

        let needsWidthScale = origW > maxWidth
        let needsHeightScale = maxHeight.map { origH > $0 } ?? false
        guard needsWidthScale || needsHeightScale else { return image }

        var newW = origW
        var newH = origH

        if origW > maxWidth {
            let ratio = maxWidth / origW
            newW = maxWidth
            newH = origH * ratio
        }

        if let maxH = maxHeight, newH > maxH {
            let ratio = maxH / newH
            newW *= ratio
            newH = maxH
        }

        let intW = Int(round(newW))
        let intH = Int(round(newH))

        guard let context = CGContext(
            data: nil,
            width: intW,
            height: intH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: intW, height: intH))

        guard let resizedCG = context.makeImage() else { return image }
        return NSImage(cgImage: resizedCG, size: NSSize(width: intW, height: intH))
    }

    // MARK: - Compress

    private func compressImage(_ image: NSImage, format: OutputFormat) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }

        switch format {
        case .original, .png:
            return bitmap.representation(using: .png, properties: [:])
        case .jpeg:
            return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
        case .heic:
            return heicData(from: bitmap, quality: quality)
        }
    }

    private func heicData(from bitmap: NSBitmapImageRep, quality: Double) -> Data? {
        guard let cgImage = bitmap.cgImage else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data, "public.heic" as CFString, 1, nil
        ) else { return nil }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    // MARK: - Clipboard Monitor

    private func startClipboardMonitor() {
        stopClipboardMonitor()
        lastChangeCount = NSPasteboard.general.changeCount
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboardForNewImage()
        }
    }

    private func stopClipboardMonitor() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
    }

    private func checkClipboardForNewImage() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard NSImage(pasteboard: pasteboard) != nil else { return }

        // Brief delay to ensure clipboard is fully written
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.shrinkClipboardImage()
            // Update changeCount after our own write to avoid re-triggering
            self?.lastChangeCount = NSPasteboard.general.changeCount
        }
    }

    // MARK: - Clipboard Write

    private func writeToClipboard(_ data: Data, format: OutputFormat) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let type: NSPasteboard.PasteboardType
        switch format {
        case .png, .original: type = .png
        case .jpeg: type = NSPasteboard.PasteboardType("public.jpeg")
        case .heic: type = NSPasteboard.PasteboardType("public.heic")
        }
        pasteboard.setData(data, forType: type)

        // Also set TIFF for broad compatibility
        if let image = NSImage(data: data), let tiff = image.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
        }
    }
}
