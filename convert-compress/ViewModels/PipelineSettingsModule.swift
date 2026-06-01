import Foundation
import Observation

@MainActor
@Observable
final class PipelineSettingsModule {
    private typealias Keys = StorageKeys.Pipeline

    var resizeMode: ResizeMode = .resize {
        didSet {
            persistResizeMode()
            notifyConfigurationChanged()
        }
    }
    var resizeWidth: String = "" {
        didSet {
            UserDefaults.standard.set(resizeWidth, forKey: Keys.resizeWidth)
            notifyConfigurationChanged()
        }
    }
    var resizeHeight: String = "" {
        didSet {
            UserDefaults.standard.set(resizeHeight, forKey: Keys.resizeHeight)
            notifyConfigurationChanged()
        }
    }
    var resizeLongEdge: String = "" {
        didSet {
            UserDefaults.standard.set(resizeLongEdge, forKey: Keys.resizeLongEdge)
            notifyConfigurationChanged()
        }
    }

    var selectedFormat: ImageFormat? = nil {
        didSet {
            UserDefaults.standard.set(selectedFormat?.id, forKey: Keys.selectedFormat)
            applyRestrictions(for: selectedFormat)
            notifyConfigurationChanged()
        }
    }
    private(set) var allowedSquareSizes: [Int]? = nil
    var recentFormats: [ImageFormat] = [] {
        didSet {
            UserDefaults.standard.set(recentFormats.map(\.id), forKey: Keys.recentFormats)
        }
    }

    var compressionPercent: Double = 0.8 {
        didSet {
            UserDefaults.standard.set(compressionPercent, forKey: Keys.compressionPercent)
            notifyConfigurationChanged()
        }
    }
    var flipV: Bool = false {
        didSet {
            UserDefaults.standard.set(flipV, forKey: Keys.flipV)
            notifyConfigurationChanged()
        }
    }
    var removeBackground: Bool = false {
        didSet {
            UserDefaults.standard.set(removeBackground, forKey: Keys.removeBackground)
            notifyConfigurationChanged()
        }
    }
    var removeMetadata: Bool = false {
        didSet {
            UserDefaults.standard.set(removeMetadata, forKey: Keys.removeMetadata)
            notifyConfigurationChanged()
        }
    }

    @ObservationIgnored var sourceSizeForRestrictedFormat: (() -> CGSize?)?
    @ObservationIgnored var onConfigurationChanged: ((ProcessingConfiguration) -> Void)?

    @ObservationIgnored private var isBatchUpdating = false
    @ObservationIgnored private var lastNotifiedConfiguration: ProcessingConfiguration?

    init() {
        loadPersistedState()
        applyRestrictions(for: selectedFormat)
        lastNotifiedConfiguration = currentConfiguration
    }

    var currentConfiguration: ProcessingConfiguration {
        let caps = selectedFormat.map { ImageIOCapabilities.shared.capabilities(for: $0) }

        return ProcessingConfiguration(
            resizeMode: resizeMode,
            resizeWidth: resizeWidth,
            resizeHeight: resizeHeight,
            resizeLongEdge: resizeLongEdge,
            selectedFormat: selectedFormat,
            compressionPercent: caps?.supportsQuality == false ? 0 : compressionPercent,
            flipV: flipV,
            removeMetadata: caps?.supportsMetadata == false ? false : removeMetadata,
            removeBackground: removeBackground
        )
    }

    var pinnedWritableFormats: [ImageFormat] {
        pinnedFormatCandidates
            .filter { ImageIOCapabilities.shared.supportsWriting(utType: $0.utType) }
    }

    var otherWritableFormats: [ImageFormat] {
        let pinnedIds = Set(pinnedWritableFormats.map(\.id))
        return ImageIOCapabilities.shared
            .writableFormats()
            .filter { !pinnedIds.contains($0.id) }
            .sorted { $0.displayName < $1.displayName }
    }

    var shouldShowCompressionControl: Bool {
        selectedFormatCapabilities?.supportsQuality ?? true
    }

    var shouldShowMetadataControl: Bool {
        selectedFormatCapabilities?.supportsMetadata ?? true
    }

    func selectFormat(_ format: ImageFormat?) {
        selectedFormat = format
        if let format {
            bumpRecentFormats(format)
        }
    }

    func bumpRecentFormats(_ format: ImageFormat) {
        var recents = RecentList(recentFormats, maxCount: 3)
        recents.insert(format)
        recentFormats = recents.elements
    }

    func applyConfiguration(_ configuration: ProcessingConfiguration) {
        withBatchUpdate {
            resizeMode = configuration.resizeMode
            resizeWidth = configuration.resizeWidth
            resizeHeight = configuration.resizeHeight
            resizeLongEdge = configuration.resizeLongEdge
            selectedFormat = configuration.selectedFormat
            compressionPercent = configuration.compressionPercent
            flipV = configuration.flipV
            removeMetadata = configuration.removeMetadata
            removeBackground = configuration.removeBackground
        }
    }

    private func loadPersistedState() {
        let defaults = UserDefaults.standard

        withBatchUpdate(notifyAtEnd: false) {
            if let modeRaw = defaults.string(forKey: Keys.resizeMode) {
                resizeMode = (modeRaw == "resize") ? .resize : .crop
            }
            if let width = defaults.string(forKey: Keys.resizeWidth) {
                resizeWidth = width
            }
            if let height = defaults.string(forKey: Keys.resizeHeight) {
                resizeHeight = height
            }
            if let longEdge = defaults.string(forKey: Keys.resizeLongEdge) {
                resizeLongEdge = longEdge
            }

            if let selectedFormatIdentifier = defaults.string(forKey: Keys.selectedFormat),
               let persistedFormat = ImageIOCapabilities.shared.format(forIdentifier: selectedFormatIdentifier),
               ImageIOCapabilities.shared.supportsWriting(utType: persistedFormat.utType) {
                selectedFormat = persistedFormat
            }
            if let raw = defaults.array(forKey: Keys.recentFormats) as? [String] {
                let mapped = raw.compactMap { ImageIOCapabilities.shared.format(forIdentifier: $0) }
                if !mapped.isEmpty {
                    recentFormats = Array(mapped.prefix(3))
                }
            }

            if defaults.object(forKey: Keys.compressionPercent) != nil {
                compressionPercent = defaults.double(forKey: Keys.compressionPercent)
            }
            if defaults.object(forKey: Keys.flipV) != nil {
                flipV = defaults.bool(forKey: Keys.flipV)
            }
            if defaults.object(forKey: Keys.removeBackground) != nil {
                removeBackground = defaults.bool(forKey: Keys.removeBackground)
            }
            if defaults.object(forKey: Keys.removeMetadata) != nil {
                removeMetadata = defaults.bool(forKey: Keys.removeMetadata)
            }
        }
    }

    private func withBatchUpdate(notifyAtEnd: Bool = true, _ update: () -> Void) {
        isBatchUpdating = true
        update()
        isBatchUpdating = false

        if notifyAtEnd {
            notifyConfigurationChanged()
        }
    }

    private func notifyConfigurationChanged() {
        guard !isBatchUpdating else { return }

        let configuration = currentConfiguration
        guard configuration != lastNotifiedConfiguration else { return }

        lastNotifiedConfiguration = configuration
        onConfigurationChanged?(configuration)
    }

    private func persistResizeMode() {
        UserDefaults.standard.set(resizeMode == .resize ? "resize" : "crop", forKey: Keys.resizeMode)
    }

    private func applyRestrictions(for format: ImageFormat?) {
        allowedSquareSizes = RestrictedFormatSizing.allowedSquareSizes(for: format)
        guard allowedSquareSizes != nil else { return }

        let sourceSize = sourceSizeForRestrictedFormat?() ?? .zero
        guard let side = RestrictedFormatSizing.targetSquareSide(
            sourceSize: sourceSize,
            resize: currentConfiguration.resizeSpecification,
            format: format
        ) else {
            return
        }

        resizeMode = .crop
        resizeWidth = String(side)
        resizeHeight = String(side)
    }

    private var selectedFormatCapabilities: FormatCapabilities? {
        selectedFormat.map { ImageIOCapabilities.shared.capabilities(for: $0) }
    }

    private var pinnedFormatCandidates: [ImageFormat] {
        [
            ImageFormat(utType: .avif),
            ImageFormat(utType: .png),
            ImageFormat(utType: .jpeg),
            ImageFormat(utType: .heic),
            ImageFormat(utType: .webP)
        ]
    }
}
