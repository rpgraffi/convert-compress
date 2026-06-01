import Foundation
import Observation

@MainActor
@Observable
final class ImageToolsSessionModule {
    @ObservationIgnored private let settings: PipelineSettingsModule
    @ObservationIgnored private let assets: AssetCollectionModule
    @ObservationIgnored private let encodedOutput: EncodedOutputModule
    @ObservationIgnored private let comparison: ComparisonSessionModule
    @ObservationIgnored private let export: ExportSessionModule

    init(
        settings: PipelineSettingsModule,
        assets: AssetCollectionModule,
        encodedOutput: EncodedOutputModule,
        comparison: ComparisonSessionModule,
        export: ExportSessionModule
    ) {
        self.settings = settings
        self.assets = assets
        self.encodedOutput = encodedOutput
        self.comparison = comparison
        self.export = export

        installHooks()
    }

    func stopExport() {
        export.cancelExport()
    }

    func remove(_ asset: ImageAsset) {
        guard assets.remove(asset) else { return }
        encodedOutput.removeValue(forKey: asset.id)
        comparison.dismissIfSelected(assetIDs: [asset.id])
    }

    func clearAll() {
        export.cancelExport()
        assets.clearAll(clearSourceDirectory: export.exportDirectory == nil)
        encodedOutput.removeAll()
        comparison.dismissComparison()
    }

    func clearExported() {
        let exportedIDs = assets.clearExported()
        guard !exportedIDs.isEmpty else { return }

        for id in exportedIDs {
            encodedOutput.removeValue(forKey: id)
        }
        comparison.dismissIfSelected(assetIDs: exportedIDs)
    }

    private func installHooks() {
        settings.sourceSizeForRestrictedFormat = { [weak assets] in
            assets?.firstSourceSizeForRestrictions()
        }
        settings.onConfigurationChanged = { [weak self] _ in
            self?.configurationDidChange()
        }
        assets.onImagesChanged = { [weak self] in
            self?.assetsDidChange()
        }
    }

    private func configurationDidChange() {
        encodedOutput.scheduleProcessing()
        comparison.scheduleComparisonPreviewRefresh()
    }

    private func assetsDidChange() {
        comparison.refreshComparisonPreviewIfNeeded()
    }
}
