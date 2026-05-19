import Foundation

enum ImageOperationError: LocalizedError {
    case loadFailed
    case exportFailed
    case backgroundRemovalUnavailable
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .loadFailed:
            String(localized: "The image could not be loaded.")
        case .exportFailed:
            String(localized: "The image could not be exported.")
        case .backgroundRemovalUnavailable:
            String(localized: "Background removal is unavailable for this image.")
        case .permissionDenied:
            String(localized: "Permission to access this file or folder was denied.")
        }
    }
}
