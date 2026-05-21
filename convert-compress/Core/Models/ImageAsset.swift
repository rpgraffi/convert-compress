import Foundation
import AppKit

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
    var originalFormat: ImageFormat?

    init(url: URL) {
        self.id = UUID()
        self.originalURL = url.standardizedFileURL
        self.workingURL = url.standardizedFileURL
        self.thumbnail = nil
        self.isEdited = false
        self.backupURL = nil
        self.originalPixelSize = nil
        self.originalFileSizeBytes = nil
        self.originalFormat = nil
    }
}
