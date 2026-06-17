import Foundation
import UniformTypeIdentifiers

struct ExportDestinationRequest {
    let asset: ImageAsset
    let index: Int
    let totalCount: Int
    let configuration: ProcessingConfiguration
    let outputUTType: UTType

    static func planned(
        asset: ImageAsset,
        index: Int,
        totalCount: Int,
        configuration: ProcessingConfiguration
    ) -> ExportDestinationRequest {
        let outputUTType = ProcessedImageEncoder.decideUTTypeForExport(
            originalURL: asset.originalURL,
            requestedFormat: configuration.selectedFormat ?? asset.originalFormat
        )
        return ExportDestinationRequest(
            asset: asset,
            index: index,
            totalCount: totalCount,
            configuration: configuration,
            outputUTType: outputUTType
        )
    }
}

