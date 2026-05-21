import SwiftUI

@MainActor
final class ImageToolsModules {
    let settings: PipelineSettingsModule
    let assets: AssetCollectionModule
    let encodedOutput: EncodedOutputModule
    let comparison: ComparisonSessionModule
    let export: ExportSessionModule
    let presets: PresetLibraryModule

    init() {
        let settings = PipelineSettingsModule()
        let assets = AssetCollectionModule()
        let encodedOutput = EncodedOutputModule(settings: settings, assets: assets)
        let comparison = ComparisonSessionModule(
            settings: settings,
            assets: assets,
            encodedOutput: encodedOutput
        )
        let export = ExportSessionModule(
            settings: settings,
            assets: assets,
            encodedOutputCache: encodedOutput.cache
        )
        let presets = PresetLibraryModule(settings: settings)

        settings.sourceSizeForRestrictedFormat = { [weak assets] in
            assets?.firstSourceSizeForRestrictions()
        }
        settings.onConfigurationChanged = { [weak encodedOutput, weak comparison] _ in
            encodedOutput?.scheduleProcessing()
            comparison?.scheduleComparisonPreviewRefresh()
        }

        assets.shouldClearSourceDirectoryOnClear = { [weak export] in
            export?.exportDirectory == nil
        }
        assets.onImagesChanged = { [weak comparison] in
            comparison?.refreshComparisonPreviewIfNeeded()
        }
        assets.onAssetRemoved = { [weak encodedOutput, weak comparison] assetID in
            encodedOutput?.removeValue(forKey: assetID)
            comparison?.dismissIfSelected(assetIDs: [assetID])
        }
        assets.onAllAssetsCleared = { [weak encodedOutput, weak comparison] in
            encodedOutput?.removeAll()
            comparison?.dismissComparison()
        }
        assets.onExportedAssetsCleared = { [weak encodedOutput, weak comparison] exportedIDs in
            for id in exportedIDs {
                encodedOutput?.removeValue(forKey: id)
            }
            comparison?.dismissIfSelected(assetIDs: exportedIDs)
        }

        self.settings = settings
        self.assets = assets
        self.encodedOutput = encodedOutput
        self.comparison = comparison
        self.export = export
        self.presets = presets
    }
}

extension View {
    @MainActor
    func imageToolsEnvironment(_ modules: ImageToolsModules) -> some View {
        self
            .environment(modules.settings)
            .environment(modules.assets)
            .environment(modules.encodedOutput)
            .environment(modules.comparison)
            .environment(modules.export)
            .environment(modules.presets)
    }
}
