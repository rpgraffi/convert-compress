import Foundation
import AppKit
import UniformTypeIdentifiers

struct ImageAsset: Identifiable, Hashable {
    let id: UUID
    var originalURL: URL
    var workingURL: URL
    var thumbnail: NSImage?
    var isEdited: Bool
    var backupURL: URL?

    // Metadata
    var originalPixelSize: CGSize?
    var originalFileSizeBytes: Int?

    init(url: URL) {
        self.id = UUID()
        self.originalURL = url.standardizedFileURL
        self.workingURL = url.standardizedFileURL
        self.thumbnail = nil
        self.isEdited = false
        self.backupURL = nil
        self.originalPixelSize = nil
        self.originalFileSizeBytes = nil
    }
}

struct ImageFormat: Identifiable, Hashable, Equatable, Codable {
    let utType: UTType

    var id: String { utType.identifier }

    var displayName: String {
        let ext = preferredFilenameExtension
        if !ext.isEmpty && ext != "img" { return ext.uppercased() }
        let id = utType.identifier
        if let last = id.split(separator: ".").last, last.count <= 8 {
            return last.uppercased()
        }
        return (utType.localizedDescription ?? id).uppercased()
    }

    var preferredFilenameExtension: String {
        ImageIOCapabilities.shared.preferredFilenameExtension(for: utType)
    }

    var fullName: String {
        utType.localizedDescription ?? utType.identifier
    }
    
    // MARK: - Codable
    
    init(utType: UTType) {
        self.utType = utType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        guard let format = ImageIOCapabilities.shared.format(forIdentifier: identifier) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown image format: \(identifier)"
            )
        }
        self.utType = format.utType
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(utType.identifier)
    }
}

struct FormatCapabilities {
    let isReadable: Bool
    let isWritable: Bool
    let supportsLossless: Bool
    let supportsQuality: Bool
    let supportsMetadata: Bool
    let supportsAlpha: Bool
    let resizeRestricted: Bool
}

enum ResizeMode: String, Codable {
    case resize
    case crop
}

