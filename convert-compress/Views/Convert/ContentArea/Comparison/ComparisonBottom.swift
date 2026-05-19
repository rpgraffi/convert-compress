import SwiftUI

struct ComparisonBottom: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    
    let asset: ImageAsset
    
    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                imageInfoBadges(isOriginal: true)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                imageInfoBadges(isOriginal: false)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(16)
    }
    
    // MARK: - Image Info Badges
    
    private func imageInfoBadges(isOriginal: Bool) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isOriginal {
                SingleLineOverlayBadge(text: String(localized: "Original"), padding: 4)
            } else {
                SingleLineOverlayBadge(text: String(localized: "Preview"), padding: 4)
            }
            
            // Format badge
            if let format = isOriginal ? originalFormat : targetFormat {
                SingleLineOverlayBadge(text: format.displayName, padding: 4)
            }
            
            // Resolution badge
            if let size = isOriginal ? asset.originalPixelSize : targetPixelSize {
                SingleLineOverlayBadge(text: "\(Int(size.width))×\(Int(size.height))", padding: 4)
            }
            
            // File size badge
            if let bytes = isOriginal ? asset.originalFileSizeBytes : outputBytes {
                SingleLineOverlayBadge(text: FileSizeFormat.string(forByteCount: bytes), padding: 4)
            }
            
            // Savings badges (only for preview/processed side)
            if !isOriginal,
               let original = asset.originalFileSizeBytes,
               let output = outputBytes,
               original != output {
                let difference = original - output
                let sign = difference > 0 ? "-" : "+"
                let absValue = abs(difference)
                let percentChange = Int(round(Double(absValue) / Double(original) * 100))
                
                SingleLineOverlayBadge(text: "\(sign)\(FileSizeFormat.string(forByteCount: absValue))", padding: 4)
                SingleLineOverlayBadge(text: "\(sign)\(percentChange)%", padding: 4)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var originalFormat: ImageFormat? {
        ImageIOCapabilities.shared.formatForURL(asset.originalURL)
    }
    
    private var targetFormat: ImageFormat? {
        vm.selectedFormat ?? originalFormat
    }
    
    private var targetPixelSize: CGSize? {
        vm.targetSize(for: asset)
    }

    private var outputBytes: Int? {
        vm.outputByteCount(for: asset.id)
    }
}

