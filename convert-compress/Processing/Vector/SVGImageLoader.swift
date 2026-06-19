import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct SVGImageLoader: VectorImageLoader {
    private static let defaultSize = CGSize(width: 1024, height: 1024)

    static func canHandle(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "svg" || ext == "svgz"
    }

    static var supportedUTTypes: [UTType] { [.svg] }

    static func intrinsicSize(for url: URL) throws -> CGSize {
        let data = try Data(contentsOf: url)
        let content = String(data: data, encoding: .utf8) ?? ""
        return resolveIntrinsicSize(svgContent: content, nsImage: NSImage(contentsOf: url))
    }

    static func embeddedPatternRasterImage(from url: URL) throws -> NSImage? {
        guard canHandle(url) else { return nil }

        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8),
              let imageData = embeddedRasterPatternData(in: content),
              let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    // MARK: - SVG XML Parsing

    static func parseIntrinsicSize(from svgContent: String) -> CGSize? {
        guard let tagRange = svgContent.range(of: "<svg[^>]*>", options: .regularExpression) else { return nil }
        let tag = String(svgContent[tagRange])

        if let w = numericAttribute("width", in: tag),
           let h = numericAttribute("height", in: tag),
           w > 0, h > 0 {
            return CGSize(width: w, height: h)
        }

        if let vb = viewBox(in: tag), vb.width > 0, vb.height > 0 {
            return CGSize(width: vb.width, height: vb.height)
        }

        return nil
    }

    /// Detects SVG markup in a string and writes it to a temporary .svg file.
    static func writeTempFile(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let isSVG = trimmed.hasPrefix("<svg") || (trimmed.hasPrefix("<?xml") && trimmed.contains("<svg"))
        guard isSVG, let data = trimmed.data(using: .utf8) else { return nil }
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("paste_" + UUID().uuidString + ".svg")
        
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
    
    // MARK: - Private Helpers

    private static func resolveIntrinsicSize(svgContent: String, nsImage: NSImage?) -> CGSize {
        if let parsed = parseIntrinsicSize(from: svgContent) {
            return parsed
        }
        if let img = nsImage, let rep = img.representations.first,
           rep.pixelsWide > 0, rep.pixelsHigh > 0 {
            return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        return defaultSize
    }

    private static func embeddedRasterPatternData(in svgContent: String) -> Data? {
        let objectBoundingPattern = #"<pattern\b[^>]*patternContentUnits\s*=\s*["']objectBoundingBox["']"#
        let rectPatternFill = #"<rect\b[^>]*fill\s*=\s*["']url\("#
        let imageDataURL = #"(?:xlink:href|href)\s*=\s*["']data:image/[^;]+;base64,([^"']+)["']"#

        guard hasMatch(objectBoundingPattern, in: svgContent),
              hasMatch(rectPatternFill, in: svgContent),
              let base64 = firstCapture(imageDataURL, in: svgContent),
              let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            return nil
        }
        return data
    }

    private static func numericAttribute(_ name: String, in tag: String) -> CGFloat? {
        let pattern = "\(name)\\s*=\\s*[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
              let range = Range(match.range(at: 1), in: tag) else { return nil }
        let raw = String(tag[range]).trimmingCharacters(in: .whitespaces)
        if raw.contains("%") { return nil }
        let numeric = raw.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        return Double(numeric).map { CGFloat($0) }
    }

    private static func viewBox(in tag: String) -> CGRect? {
        let pattern = "viewBox\\s*=\\s*[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
              let range = Range(match.range(at: 1), in: tag) else { return nil }
        let parts = String(tag[range])
            .split { $0 == " " || $0 == "," }
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4 else { return nil }
        return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }

    private static func hasMatch(_ pattern: String, in content: String) -> Bool {
        firstCapture("(\(pattern))", in: content) != nil
    }

    private static func firstCapture(_ pattern: String, in content: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else {
            return nil
        }
        return String(content[range])
    }
}
