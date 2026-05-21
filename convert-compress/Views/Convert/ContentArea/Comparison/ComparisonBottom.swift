import SwiftUI

struct ComparisonBottom: View {
    let displayInfo: ImageAssetDisplayInfo
    
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
            if let format = isOriginal ? displayInfo.originalFormat : displayInfo.targetFormat {
                SingleLineOverlayBadge(text: format.displayName, padding: 4)
            }
            
            // Resolution badge
            if let size = isOriginal ? displayInfo.originalPixelSize : displayInfo.targetPixelSize {
                SingleLineOverlayBadge(text: "\(Int(size.width))×\(Int(size.height))", padding: 4)
            }
            
            // File size badge
            if let bytes = isOriginal ? displayInfo.originalFileSizeBytes : displayInfo.outputByteCount {
                SingleLineOverlayBadge(text: FileSizeFormat.string(forByteCount: bytes), padding: 4)
            }
            
            // Savings badges (only for preview/processed side)
            if !isOriginal,
               let difference = displayInfo.outputByteDifference,
               let percentChange = displayInfo.outputByteChangePercent {
                let sign = difference > 0 ? "-" : "+"
                let absValue = abs(difference)
                
                SingleLineOverlayBadge(text: "\(sign)\(FileSizeFormat.string(forByteCount: absValue))", padding: 4)
                SingleLineOverlayBadge(text: "\(sign)\(percentChange)%", padding: 4)
            }
        }
    }
}

