import Foundation

struct ExportAssetFailure: Identifiable {
    let id = UUID()
    let assetID: UUID
    let originalURL: URL
    let message: String

    init(asset: ImageAsset, error: Error) {
        self.assetID = asset.id
        self.originalURL = asset.originalURL
        self.message = error.localizedDescription
    }
}

enum ExportResultStatus: String {
    case succeeded
    case completedWithFailures
    case cancelled
    case accessDenied
    case replaceCancelled
}

struct ExportResult {
    let status: ExportResultStatus
    let updatedImages: [ImageAsset]
    let failures: [ExportAssetFailure]
    let completedCount: Int
    let totalCount: Int
    let deniedDirectory: URL?

    var exportedCount: Int {
        updatedImages.filter(\.isEdited).count
    }

    var editedURLs: [URL] {
        updatedImages.compactMap { $0.isEdited ? $0.workingURL : nil }
    }

    var shouldRunPostExportSideEffects: Bool {
        switch status {
        case .succeeded, .completedWithFailures, .cancelled:
            exportedCount > 0
        case .accessDenied, .replaceCancelled:
            false
        }
    }

    static func succeeded(updatedImages: [ImageAsset], totalCount: Int) -> ExportResult {
        ExportResult(
            status: .succeeded,
            updatedImages: updatedImages,
            failures: [],
            completedCount: totalCount,
            totalCount: totalCount,
            deniedDirectory: nil
        )
    }

    static func completedWithFailures(
        updatedImages: [ImageAsset],
        failures: [ExportAssetFailure],
        completedCount: Int,
        totalCount: Int
    ) -> ExportResult {
        ExportResult(
            status: .completedWithFailures,
            updatedImages: updatedImages,
            failures: failures,
            completedCount: completedCount,
            totalCount: totalCount,
            deniedDirectory: nil
        )
    }

    static func cancelled(
        updatedImages: [ImageAsset],
        failures: [ExportAssetFailure],
        completedCount: Int,
        totalCount: Int
    ) -> ExportResult {
        ExportResult(
            status: .cancelled,
            updatedImages: updatedImages,
            failures: failures,
            completedCount: completedCount,
            totalCount: totalCount,
            deniedDirectory: nil
        )
    }

    static func accessDenied(directory: URL, initialImages: [ImageAsset], totalCount: Int) -> ExportResult {
        ExportResult(
            status: .accessDenied,
            updatedImages: initialImages,
            failures: [],
            completedCount: 0,
            totalCount: totalCount,
            deniedDirectory: directory
        )
    }

    static func replaceCancelled(initialImages: [ImageAsset], totalCount: Int) -> ExportResult {
        ExportResult(
            status: .replaceCancelled,
            updatedImages: initialImages,
            failures: [],
            completedCount: 0,
            totalCount: totalCount,
            deniedDirectory: nil
        )
    }
}
