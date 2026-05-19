import Foundation
import UniformTypeIdentifiers

/// Cached result of a fully processed image (encoded data + format).
/// Stored alongside the configuration that produced it so consumers
/// can validate freshness before reuse.
struct ProcessedImageData {
    let data: Data
    let uti: UTType
    let configuration: ProcessingConfiguration

    var encodedOutput: (data: Data, uti: UTType) {
        (data, uti)
    }

    func isFresh(for configuration: ProcessingConfiguration) -> Bool {
        self.configuration == configuration
    }

    func encodedOutput(ifFreshFor configuration: ProcessingConfiguration) -> (data: Data, uti: UTType)? {
        guard isFresh(for: configuration) else {
            return nil
        }
        return encodedOutput
    }
}
