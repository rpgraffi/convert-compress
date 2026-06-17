import Foundation

/// Single source of truth for every UserDefaults / NSUbiquitousKeyValueStore key
/// used by the app. Grouped by feature to keep the namespace explicit.
///
/// Existing key literals are preserved for backwards compatibility with installs.
/// When introducing a new key prefer the `newKey(_:)` helper so future keys share
/// a single, predictable namespace.
enum StorageKeys {
    private static func newKey(_ suffix: String) -> String {
        "\(AppConstants.bundleIdentifier).\(suffix)"
    }

    // MARK: - App Preferences (local)

    enum Preferences {
        static let revealExportInFinder = "\(AppConstants.bundleIdentifier).reveal_export_in_finder"
        static let keepFolderStructure  = "\(AppConstants.bundleIdentifier).keep_folder_structure"
    }

    // MARK: - Pipeline Settings (local, persisted via Combine sinks)

    enum Pipeline {
        static let exportDirectory    = "convert-compress.export_directory.v1"
        static let resizeMode         = "convert-compress.resize_mode.v1"
        static let resizeWidth        = "convert-compress.resize_width.v1"
        static let resizeHeight       = "convert-compress.resize_height.v1"
        static let resizeLongEdge     = "convert-compress.resize_long_edge.v1"
        static let selectedFormat     = "convert-compress.selected_format.v1"
        static let recentFormats      = "convert-compress.recent_formats.v1"
        static let compressionPercent = "convert-compress.compression_percent.v1"
        static let flipV              = "convert-compress.flip_v.v1"
        static let removeBackground   = "convert-compress.remove_background.v1"
        static let removeMetadata     = "convert-compress.remove_metadata.v1"
    }

    // MARK: - Export Rename (local)

    enum ExportRename {
        static let template         = "\(AppConstants.bundleIdentifier).export_rename.template.v1"
        static let dateFormatPreset = "\(AppConstants.bundleIdentifier).export_rename.date_format_preset.v1"
    }

    // MARK: - Usage Tracking (local)

    enum Usage {
        static let events = "image_tools.usage_events.v1"
    }

    // MARK: - Rating Prompt (local)

    enum Rating {
        static let hasShown = "image_tools.rating.has_shown"
        static let declined = "image_tools.rating.declined"
    }

    // MARK: - Presets (iCloud)

    enum Presets {
        static let store = "\(AppConstants.bundleIdentifier).presets"
    }
}
