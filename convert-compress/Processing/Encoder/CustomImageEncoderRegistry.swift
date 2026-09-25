import UniformTypeIdentifiers

struct CustomImageEncoderRegistry {
    private static let encoders: [CustomImageEncoder] = [
        WebPEncoder()
    ]

    static func encoder(for utType: UTType) -> CustomImageEncoder? {
        encoders.first { $0.canEncode(utType: utType) }
    }
}
