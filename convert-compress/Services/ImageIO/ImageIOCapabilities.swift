import Foundation
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics

final class ImageIOCapabilities {
    static let shared = ImageIOCapabilities()

    private var readableTypes: Set<String>
    private var writableTypes: Set<String>

    private init() {
        if let readIds = CGImageSourceCopyTypeIdentifiers() as? [String] {
            self.readableTypes = Set(readIds)
        } else {
            self.readableTypes = []
        }
        if let writeIds = CGImageDestinationCopyTypeIdentifiers() as? [String] {
            self.writableTypes = Set(writeIds)
        } else {
            self.writableTypes = []
        }

        // Ensure WebP appears as a writable format via SDWebImageWebPCoder
        // ImageIO may not advertise WebP as a destination type on all systems
        self.writableTypes.insert(UTType.webP.identifier)

        // Ensure AVIF appears as readable + writable via the custom AVIF encoder.
        self.readableTypes.insert(UTType.avif.identifier)
        self.writableTypes.insert(UTType.avif.identifier)

        for utType in VectorImageSupport.allSupportedUTTypes {
            self.readableTypes.insert(utType.identifier)
        }
    }

    func supportsWriting(utType: UTType) -> Bool {
        writableTypes.contains(utType.identifier)
    }

    func supportsReading(utType: UTType) -> Bool {
        readableTypes.contains(utType.identifier)
    }

    func preferredFilenameExtension(for utType: UTType) -> String {
        if utType == .jpeg { return "jpg" }
        return utType.preferredFilenameExtension ?? "img"
    }

    // MARK: - Dynamic format lists

    func writableFormats() -> [ImageFormat] {
        writableTypes.compactMap { id in
            guard let utType = UTType(id), utType.conforms(to: .image) else { return nil }
            return ImageFormat(utType: utType)
        }
    }

    // MARK: - Capabilities
    func capabilities(for format: ImageFormat) -> FormatCapabilities {
        capabilities(forUTType: format.utType)
    }

    func capabilities(forUTType utType: UTType) -> FormatCapabilities {
        let isReadable = supportsReading(utType: utType)
        let isWritable = supportsWriting(utType: utType)
        let supportsQuality = (utType == .jpeg) || (utType == UTType.heic) || (utType == UTType.webP) || (utType == .avif)
        let supportsLossless = (utType == .png) || (utType == .tiff) || (utType == .bmp) || (utType == .gif) || (utType == UTType.webP) || (utType == .avif)
        let supportsMetadata = supportsPrivacySensitiveMetadata(utType: utType)
        let supportsAlpha = supportsAlphaChannel(utType: utType)
        let resizeRestricted = sizeRestrictions(forUTType: utType) != nil
        return FormatCapabilities(
            isReadable: isReadable,
            isWritable: isWritable,
            supportsLossless: supportsLossless,
            supportsQuality: supportsQuality,
            supportsMetadata: supportsMetadata,
            supportsAlpha: supportsAlpha,
            resizeRestricted: resizeRestricted
        )
    }

    // MARK: - Privacy-sensitive metadata detection
    
    /// Determines if a format can preserve privacy-sensitive metadata through our ImageIO export path.
    /// This is used to show/hide the metadata removal control appropriately.
    private func supportsPrivacySensitiveMetadata(utType: UTType) -> Bool {
        // Only check writable formats since we can't remove metadata from formats we can't write
        guard supportsWriting(utType: utType) else { return false }

        // These formats can store metadata, but our custom encoders currently rebuild
        // them from pixels only, so exported files are already stripped.
        if utType == UTType.webP || utType == .avif {
            return false
        }
        
        // Common ImageIO-backed formats that support EXIF, XMP, GPS, or related privacy metadata.
        let privacyMetadataFormats: Set<String> = [
            UTType.jpeg.identifier,
            UTType.png.identifier,
            UTType.tiff.identifier,
            UTType.heic.identifier,
            UTType.heif.identifier,
            "public.heics",
            "public.heifs",
            "public.jpeg-2000",
            "public.jpeg-xl"
        ]
        
        if privacyMetadataFormats.contains(utType.identifier) {
            return true
        }
        
        // For other formats, check if they conform to formats that typically have EXIF
        // Most camera/photo formats support EXIF
        if let cameraRawType = UTType("public.camera-raw-image"), utType.conforms(to: cameraRawType) {
            return true
        }
        if let adobeRawType = UTType("com.adobe.raw-image"), utType.conforms(to: adobeRawType) {
            return true
        }
        
        // Additional check for formats that might support EXIF but aren't in our main list
        // This covers various RAW formats and other photo formats
        let identifier = utType.identifier.lowercased()
        let photoFormatHints = ["raw", "dng", "cr2", "nef", "orf", "arw", "rw2"]
        if photoFormatHints.contains(where: { identifier.contains($0) }) {
            return true
        }
        
        return false
    }

    // MARK: - Alpha channel support
    private func supportsAlphaChannel(utType: UTType) -> Bool {
        if utType == .png || utType == .tiff || utType == .gif || utType == UTType.heic || utType == UTType.heif || utType == UTType.webP || utType == .avif || utType == .bmp || utType == .icns {
            return true
        }
        if utType == .jpeg { return false }
        return true
    }

    // MARK: - URL helpers
    func formatForURL(_ url: URL) -> ImageFormat? {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { return nil }
        if let t = UTType(filenameExtension: ext), t.conforms(to: .image), supportsReading(utType: t) {
            return ImageFormat(utType: t)
        }
        return nil
    }

    func isReadableURL(_ url: URL) -> Bool {
        formatForURL(url) != nil
    }

    func format(forIdentifier id: String) -> ImageFormat? {
        guard let t = UTType(id), t.conforms(to: .image) else { return nil }
        return ImageFormat(utType: t)
    }

    // MARK: - Size restrictions for formats

    /// Returns the allowed square sizes for the given UTType, if any.
    /// Known cases: ICNS (fixed square set), ICO (fixed square set), PVR/PowerVR (fixed square set)
    func sizeRestrictions(forUTType utType: UTType) -> Set<Int>? {
        // ICNS
        if utType == UTType.icns {
            // Common ICNS pixel variants (backed by Apple's icon sizes)
            return Set([16, 32, 128, 256, 512])
        }
        // ICO – identifier varies; resolve via extension when possible
        if utType.identifier.lowercased().contains("ico") || utType.preferredFilenameExtension == "ico" {
            return Set([16, 32, 48, 128, 256])
        }
        // PVR/PowerVR – treat as fixed square sizes for simplicity
        let id = utType.identifier.lowercased()
        if id.contains("pvr") || id.contains("powervr") {
            return Set([16, 32, 64, 128, 256, 512, 1024, 2048, 4096])
        }
        return nil
    }

} 