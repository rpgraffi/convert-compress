import Foundation
import UniformTypeIdentifiers

extension ImageToolsViewModel {
    var pinnedWritableFormats: [ImageFormat] {
        pinnedFormatCandidates
            .filter { ImageIOCapabilities.shared.supportsWriting(utType: $0.utType) }
    }

    var otherWritableFormats: [ImageFormat] {
        let pinnedIds = Set(pinnedWritableFormats.map(\.id))
        return ImageIOCapabilities.shared
            .writableFormats()
            .filter { !pinnedIds.contains($0.id) }
            .sorted { $0.displayName < $1.displayName }
    }

    var shouldShowCompressionControl: Bool {
        selectedFormatCapabilities?.supportsQuality ?? true
    }

    var shouldShowMetadataControl: Bool {
        selectedFormatCapabilities?.supportsMetadata ?? true
    }

    func updateRestrictions(for format: ImageFormat?) {
        allowedSquareSizes = RestrictedFormatSizing.allowedSquareSizes(for: format)
    }

    func onSelectedFormatChanged(_ format: ImageFormat?) {
        updateRestrictions(for: format)
        guard allowedSquareSizes != nil else { return }
        
        // Choose a reference size from first asset (prefer cached value)
        guard let firstImage = images.first else { return }
        let sourceSize = firstImage.originalPixelSize ?? .zero
        
        if let side = RestrictedFormatSizing.targetSquareSide(
            sourceSize: sourceSize,
            resize: currentConfiguration.resizeSpecification,
            format: format
        ) {
            resizeMode = .crop
            resizeWidth = String(side)
            resizeHeight = String(side)
        }
    }

    private var selectedFormatCapabilities: FormatCapabilities? {
        selectedFormat.map { ImageIOCapabilities.shared.capabilities(for: $0) }
    }

    private var pinnedFormatCandidates: [ImageFormat] {
        [
            ImageFormat(utType: .png),
            ImageFormat(utType: .jpeg),
            ImageFormat(utType: .heic),
            ImageFormat(utType: .webP)
        ]
    }
}
