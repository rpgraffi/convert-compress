import CoreGraphics
import Foundation
import UniformTypeIdentifiers

protocol VectorImageLoader {
    static func canHandle(_ url: URL) -> Bool
    static var supportedUTTypes: [UTType] { get }
    static func intrinsicSize(for url: URL) throws -> CGSize
}
