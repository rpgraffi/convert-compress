import Foundation
import UniformTypeIdentifiers

struct ExportFilenameContext {
    let asset: ImageAsset
    let index: Int
    let totalCount: Int
    let configuration: ProcessingConfiguration
    let outputUTType: UTType
    let outputSize: CGSize?
    let today: Date
    let created: Date?
    let modified: Date?
}

struct ExportFilenameBuilder {
    let settings: ExportRenameSettings

    func basename(for context: ExportFilenameContext, filenameExtension: String) -> String {
        let originalStem = sanitizedOriginalStem(for: context.asset)
        guard settings.isEnabled else {
            return trimmed(originalStem, filenameExtension: filenameExtension)
        }

        let template = settings.sanitizedTemplate
        guard !template.isEmpty else {
            return trimmed(originalStem, filenameExtension: filenameExtension)
        }

        let expanded = expandedTemplate(template, context: context, originalStem: originalStem)
        let sanitized = FilenameSanitizer.sanitizeBasename(expanded)
        let fallback = sanitized.isEmpty ? originalStem : sanitized
        return trimmed(fallback, filenameExtension: filenameExtension)
    }

    private func expandedTemplate(_ template: String, context: ExportFilenameContext, originalStem: String) -> String {
        var result = ""
        var current = template.startIndex

        for match in RenameTokenParser.matches(in: template) {
            result += template[current..<match.range.lowerBound]
            result += replacement(for: match.token, context: context, originalStem: originalStem)
            current = match.range.upperBound
        }

        result += template[current..<template.endIndex]
        return result
    }

    private func replacement(for token: RenameToken, context: ExportFilenameContext, originalStem: String) -> String {
        switch token {
        case .originalName:
            originalStem
        case .today:
            settings.dateFormatPreset.string(from: context.today)
        case .created:
            settings.dateFormatPreset.string(from: context.created ?? context.today)
        case .modified:
            settings.dateFormatPreset.string(from: context.modified ?? context.today)
        case .indexUp(let width):
            padded(context.index, width: width)
        case .indexDown(let width):
            padded(max(context.totalCount - context.index - 1, 0), width: width)
        case .width:
            pixelValue(context.outputSize?.width)
        case .height:
            pixelValue(context.outputSize?.height)
        case .quality:
            qualityValue(for: context)
        }
    }

    private func sanitizedOriginalStem(for asset: ImageAsset) -> String {
        let stem = asset.originalURL.deletingPathExtension().lastPathComponent
        let sanitized = FilenameSanitizer.sanitizeBasename(stem)
        return sanitized.isEmpty ? String(localized: "Untitled") : sanitized
    }

    private func trimmed(_ basename: String, filenameExtension: String) -> String {
        FilenameSanitizer.trimBasename(basename, filenameExtension: filenameExtension)
    }

    private func padded(_ value: Int, width: Int) -> String {
        guard width > 1 else { return String(value) }
        return String(format: "%0\(width)d", value)
    }

    private func pixelValue(_ value: CGFloat?) -> String {
        guard let value, value > 0 else { return "" }
        return String(Int(value.rounded()))
    }

    private func qualityValue(for context: ExportFilenameContext) -> String {
        guard ImageIOCapabilities.shared.capabilities(forUTType: context.outputUTType).supportsQuality else {
            return ""
        }
        let percent = Int((context.configuration.compressionPercent * 100).rounded())
        return String(percent)
    }
}

