import CoreImage

protocol ImageOperation {
    func transformed(_ input: CIImage) throws -> CIImage
}

extension [ImageOperation] {
    var containsResizeOperation: Bool {
        contains { $0 is ResizeOperation || $0 is CropOperation || $0 is ConstrainSizeOperation }
    }
}
