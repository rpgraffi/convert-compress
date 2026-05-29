import Foundation
import CoreImage
import UniformTypeIdentifiers

struct ProcessingPipeline {
    var operations: [ImageOperation] = []
    var removeMetadata: Bool = false
    var finalFormat: ImageFormat? = nil
    var compressionPercent: Double? = nil

    init(configuration: ProcessingConfiguration) {
        removeMetadata = configuration.removeMetadata
        finalFormat = configuration.selectedFormat
        compressionPercent = configuration.compressionPercent

        if RestrictedFormatSizing.isRestricted(configuration.selectedFormat) {
            if let format = configuration.selectedFormat {
                add(ConstrainSizeOperation(
                    targetFormat: format,
                    resize: configuration.resizeSpecification
                ))
            }
        } else if let resizeOperation = EffectiveImageSizing.resizeOperation(for: configuration.resizeSpecification) {
            add(resizeOperation)
        }

        if configuration.flipV {
            add(FlipVerticalOperation())
        }

        if configuration.removeBackground {
            add(RemoveBackgroundOperation())
        }
    }

    mutating func add(_ operation: ImageOperation) {
        operations.append(operation)
    }

    /// Write the processed image to a temporary file and return its URL.
    /// When `preEncoded` is provided, the expensive encode step is skipped.
    func renderTemporaryURL(on asset: ImageAsset, preEncoded: (data: Data, uti: UTType)? = nil) throws -> URL {
        let encoded = try preEncoded ?? processAndEncode(asset)
        let ext = ImageIOCapabilities.shared.preferredFilenameExtension(for: encoded.uti)
        let base = asset.originalURL.deletingPathExtension().lastPathComponent
        let tempFilename = base + "_tmp_" + String(UUID().uuidString.prefix(8)) + "." + ext
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(tempFilename)
        try encoded.data.write(to: outputURL, options: [.atomic])
        return outputURL
    }

    /// Process and return encoded data with the chosen UTType.
    func renderEncodedData(on asset: ImageAsset) throws -> (data: Data, uti: UTType) {
        return try processAndEncode(asset)
    }

    /// Determine the UTType that encoding will use, without rendering the image.
    func outputUTType(for asset: ImageAsset) -> UTType {
        let chosenFormat = finalFormat ?? asset.originalFormat
        return ProcessedImageEncoder.decideUTTypeForExport(originalURL: asset.originalURL, requestedFormat: chosenFormat)
    }

    // MARK: - DRY helper
    private func processAndEncode(_ asset: ImageAsset) throws -> (data: Data, uti: UTType) {
        try Task.checkCancellation()

        let originalURL = asset.originalURL
        guard let token = SandboxAccessToken(url: originalURL) else {
            throw ImageOperationError.permissionDenied
        }
        defer { token.stop() }

        var image = try loadCIImage(from: originalURL, operations: operations)
        for operation in operations {
            try Task.checkCancellation()
            image = try operation.transformed(image)
        }

        try Task.checkCancellation()

        let chosenFormat = finalFormat ?? asset.originalFormat
        let quality = compressionPercent.map { max(min($0, 1.0), 0.01) }
        let encoded = try ProcessedImageEncoder.encodeToData(ciImage: image,
                                                     originalURL: originalURL,
                                                     format: chosenFormat,
                                                     compressionQuality: quality,
                                                     stripMetadata: removeMetadata)
        try Task.checkCancellation()

        return encoded
    }
}
