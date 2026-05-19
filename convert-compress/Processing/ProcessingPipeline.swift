import Foundation
import CoreImage
import UniformTypeIdentifiers

struct ProcessingPipeline {
    var operations: [ImageOperation] = []
    var removeMetadata: Bool = false
    var exportDirectory: URL? = nil
    var folderStructureRoot: URL? = nil
    var finalFormat: ImageFormat? = nil
    var compressionPercent: Double? = nil

    mutating func add(_ operation: ImageOperation) {
        operations.append(operation)
    }

    /// Process an asset and write it to its destination.
    /// When `preEncoded` is provided (e.g. from the estimation cache),
    /// the expensive encode step is skipped entirely.
    func run(
        on asset: ImageAsset,
        preEncoded: (data: Data, uti: UTType)? = nil,
        writeAccess: ExportWriteAccess
    ) throws -> ImageAsset {
        let currentURL = asset.originalURL

        guard let sourceToken = SandboxAccessToken(url: currentURL) else {
            throw ImageOperationError.permissionDenied
        }
        defer { sourceToken.stop() }

        let encoded = try preEncoded ?? processAndEncode(from: currentURL)
        let plan = destinationResolver.destinationPlan(for: asset, uti: encoded.uti)

        let destParent = plan.directory
        guard writeAccess.allowsWriting(to: destParent) else {
            throw ImageOperationError.permissionDenied
        }

        if !FileManager.default.fileExists(atPath: destParent.path) {
            try FileManager.default.createDirectory(at: destParent, withIntermediateDirectories: true)
        }

        let tempFilename = plan.filenameStem + "_tmp_" + String(UUID().uuidString.prefix(8)) + "." + plan.fileExtension
        let tempInDest = destParent.appendingPathComponent(tempFilename)
        try encoded.data.write(to: tempInDest, options: [.atomic])
        if FileManager.default.fileExists(atPath: plan.url.path) {
            _ = try FileManager.default.replaceItemAt(plan.url, withItemAt: tempInDest, backupItemName: nil, options: [])
        } else {
            try FileManager.default.moveItem(at: tempInDest, to: plan.url)
        }

        var updated = asset
        updated.workingURL = plan.url
        updated.isEdited = true
        return updated
    }

    /// Write the processed image to a temporary file and return its URL.
    /// When `preEncoded` is provided, the expensive encode step is skipped.
    func renderTemporaryURL(on asset: ImageAsset, preEncoded: (data: Data, uti: UTType)? = nil) throws -> URL {
        let encoded = try preEncoded ?? processAndEncode(from: asset.originalURL)
        let ext = ImageIOCapabilities.shared.preferredFilenameExtension(for: encoded.uti)
        let base = asset.originalURL.deletingPathExtension().lastPathComponent
        let tempFilename = base + "_tmp_" + String(UUID().uuidString.prefix(8)) + "." + ext
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(tempFilename)
        try encoded.data.write(to: outputURL, options: [.atomic])
        return outputURL
    }

    /// Process and return encoded data with the chosen UTType.
    func renderEncodedData(on asset: ImageAsset) throws -> (data: Data, uti: UTType) {
        return try processAndEncode(from: asset.originalURL)
    }

    // MARK: - DRY helper
    private func processAndEncode(from originalURL: URL) throws -> (data: Data, uti: UTType) {
        guard let token = SandboxAccessToken(url: originalURL) else {
            throw ImageOperationError.permissionDenied
        }
        defer { token.stop() }

        var image = try loadCIImage(from: originalURL, operations: operations)
        for operation in operations {
            image = try operation.transformed(image)
        }
        let chosenFormat = finalFormat ?? ImageExporter.inferFormat(from: originalURL)
        let quality = compressionPercent.map { max(min($0, 1.0), 0.01) }
        let encoded = try ImageExporter.encodeToData(ciImage: image,
                                                     originalURL: originalURL,
                                                     format: chosenFormat,
                                                     compressionQuality: quality,
                                                     stripMetadata: removeMetadata)
        return encoded
    }

    /// Compute the destination URL without performing any processing, matching the naming behavior of `run(on:)`.
    func plannedDestinationURL(for asset: ImageAsset) -> URL {
        let currentURL = asset.originalURL
        let chosenFormat = finalFormat ?? ImageExporter.inferFormat(from: currentURL)
        let finalUTI = ImageExporter.decideUTTypeForExport(originalURL: currentURL, requestedFormat: chosenFormat)
        let plan = destinationResolver.destinationPlan(for: asset, uti: finalUTI)
        return plan.url
    }
}

private extension ProcessingPipeline {
    var destinationResolver: ExportDestinationResolver {
        ExportDestinationResolver(
            exportDirectory: exportDirectory,
            folderStructureRoot: folderStructureRoot
        )
    }
}
