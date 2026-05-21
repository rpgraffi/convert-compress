import Foundation

struct PreviewEncode {
    enum Output {
        case ready(assetID: UUID, data: ProcessedImageData)
        case failed(assetID: UUID)

        var assetID: UUID {
            switch self {
            case .ready(let assetID, _), .failed(let assetID):
                assetID
            }
        }
    }

    static func process(
        asset: ImageAsset,
        configuration: ProcessingConfiguration
    ) -> Output {
        do {
            let pipeline = ProcessingPipeline(configuration: configuration)
            let encoded = try pipeline.renderEncodedData(on: asset)
            let result = ProcessedImageData(
                data: encoded.data,
                uti: encoded.uti,
                configuration: configuration
            )
            return .ready(assetID: asset.id, data: result)
        } catch {
            AppLogger.processing.error("Preview encode failed for \(asset.originalURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return .failed(assetID: asset.id)
        }
    }
}
