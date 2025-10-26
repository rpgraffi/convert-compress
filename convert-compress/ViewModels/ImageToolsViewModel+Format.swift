import Foundation

extension ImageToolsViewModel {
    func updateRestrictions(for format: ImageFormat?) {
        let caps = ImageIOCapabilities.shared
        if let fmt = format, let set = caps.sizeRestrictions(forUTType: fmt.utType) {
            allowedSquareSizes = set.sorted()
        } else {
            allowedSquareSizes = nil
        }
    }

    func onSelectedFormatChanged(_ format: ImageFormat?) {
        updateRestrictions(for: format)
        guard allowedSquareSizes != nil else { return }
        
        // Choose a reference size from first asset
        guard let first = images.first else { return }
        let srcSize = ImageMetadata.pixelSize(for: first.originalURL) ?? first.originalPixelSize ?? .zero
        
        let caps = ImageIOCapabilities.shared
        if let fmt = format, !caps.isValidPixelSize(srcSize, for: fmt.utType) {
            // Force resize mode and prefill suggestion
            resizeMode = .resize
            if let side = caps.suggestedSquareSide(for: fmt.utType, source: srcSize) {
                resizeWidth = String(side)
                resizeHeight = String(side)
            }
        }
    }
}
