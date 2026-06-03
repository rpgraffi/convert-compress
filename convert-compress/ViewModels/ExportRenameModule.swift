import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class ExportRenameModule {
    private typealias Keys = StorageKeys.ExportRename

    var isEnabled = false
    var template = "" {
        didSet {
            UserDefaults.standard.set(template, forKey: Keys.template)
        }
    }
    var dateFormatPreset: RenameDateFormatPreset = .dayMonthYearDots {
        didSet {
            UserDefaults.standard.set(dateFormatPreset.rawValue, forKey: Keys.dateFormatPreset)
        }
    }
    var isPopoverPresented = false

    @ObservationIgnored private let pipelineSettings: PipelineSettingsModule
    @ObservationIgnored private let assets: AssetCollectionModule
    @ObservationIgnored private var destinationResolverProvider: (@MainActor () -> ExportDestinationResolver)?

    init(settings: PipelineSettingsModule, assets: AssetCollectionModule) {
        self.pipelineSettings = settings
        self.assets = assets
        loadPersistedState()
    }

    var exportSettings: ExportRenameSettings {
        ExportRenameSettings(
            isEnabled: isEnabled,
            template: template,
            dateFormatPreset: dateFormatPreset
        )
    }

    var hasDuplicateDestinations: Bool {
        duplicateDestinations().isEmpty == false
    }

    func configureDestinationResolver(_ provider: @escaping @MainActor () -> ExportDestinationResolver) {
        destinationResolverProvider = provider
    }

    func setEnabled(_ value: Bool) {
        isEnabled = value
        isPopoverPresented = value
    }

    func setPopoverPresented(_ value: Bool) {
        isPopoverPresented = value
    }

    func setTemplate(_ value: String) {
        template = FilenameSanitizer.sanitizeTemplateInput(value)
    }

    @discardableResult
    func insert(_ tokenText: String, atUTF16Offset cursorOffset: Int) -> Int {
        let current = template
        let currentLength = (current as NSString).length
        let safeOffset = min(max(cursorOffset, 0), currentLength)
        let insertionIndex = String.Index(utf16Offset: safeOffset, in: current)
        var updated = current
        updated.insert(contentsOf: tokenText, at: insertionIndex)

        setTemplate(updated)

        let insertedLength = (tokenText as NSString).length
        return min(safeOffset + insertedLength, (template as NSString).length)
    }

    func previewFilename(for asset: ImageAsset, index: Int) -> String {
        plannedDestinationURL(for: asset, index: index).lastPathComponent
    }

    func samplePreviewFilename() -> String {
        let configuration = pipelineSettings.currentConfiguration
        let sampleSide = samplePreviewSide(for: configuration)
        var sampleAsset = ImageAsset(url: URL(fileURLWithPath: "/tmp/ImageName.jpg"))
        sampleAsset.originalPixelSize = CGSize(width: sampleSide, height: sampleSide)
        sampleAsset.originalFormat = ImageFormat(utType: UTType.jpeg)

        let request = ExportDestinationRequest(
            asset: sampleAsset,
            index: 0,
            totalCount: max(assets.images.count, 1),
            configuration: configuration,
            outputUTType: (configuration.selectedFormat ?? sampleAsset.originalFormat)?.utType ?? UTType.jpeg
        )

        return destinationResolver().destinationURL(for: request).lastPathComponent
    }

    private func loadPersistedState() {
        if let template = UserDefaults.standard.string(forKey: Keys.template) {
            self.template = FilenameSanitizer.sanitizeTemplateInput(template)
        }
        if let rawPreset = UserDefaults.standard.string(forKey: Keys.dateFormatPreset),
           let preset = RenameDateFormatPreset(rawValue: rawPreset) {
            dateFormatPreset = preset
        }
    }

    private func duplicateDestinations() -> [URL] {
        guard isEnabled, assets.images.count > 1 else { return [] }

        var seen: Set<URL> = []
        var duplicates: Set<URL> = []
        for (index, asset) in assets.images.enumerated() {
            let url = plannedDestinationURL(for: asset, index: index).standardizedFileURL
            if seen.contains(url) {
                duplicates.insert(url)
            } else {
                seen.insert(url)
            }
        }
        return Array(duplicates)
    }

    private func plannedDestinationURL(for asset: ImageAsset, index: Int) -> URL {
        let configuration = pipelineSettings.currentConfiguration
        return destinationResolver().destinationURL(
            for: .planned(
                asset: asset,
                index: index,
                totalCount: assets.images.count,
                configuration: configuration
            )
        )
    }

    private func destinationResolver() -> ExportDestinationResolver {
        destinationResolverProvider?()
            ?? ExportDestinationResolver(
                exportDirectory: nil,
                folderStructureRoot: nil,
                renameSettings: exportSettings
            )
    }

    private func samplePreviewSide(for configuration: ProcessingConfiguration) -> CGFloat {
        let candidates = [
            configuration.resizeWidth,
            configuration.resizeHeight,
            configuration.resizeLongEdge
        ]

        for candidate in candidates {
            if let value = Int(candidate), value > 0 {
                return CGFloat(value)
            }
        }

        return 1024
    }
}
