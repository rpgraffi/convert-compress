import Foundation

enum AppConstants {
    /// The localized display name of the app
    static let localizedAppName: String = {
        Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? "Convert & Compress"
    }()
    
    /// The bundle identifier of the app
    static let bundleIdentifier: String = {
        Bundle.main.bundleIdentifier ?? "raffistudio.image-tools"
    }()
}

