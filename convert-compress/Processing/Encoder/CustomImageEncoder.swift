import Foundation
import CoreGraphics
import UniformTypeIdentifiers

protocol CustomImageEncoder {
    var supportsMetadataStripping: Bool { get }
    func canEncode(utType: UTType) -> Bool
    func encode(cgImage: CGImage, pixelSize: CGSize, utType: UTType, compressionQuality: Double?, stripMetadata: Bool) throws -> Data
}
