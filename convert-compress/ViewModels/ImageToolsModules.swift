import SwiftUI

@MainActor
final class ImageToolsModules {
    let settings: PipelineSettingsModule
    let assets: AssetCollectionModule
    let rename: ExportRenameModule
    let encodedOutput: EncodedOutputModule
    let comparison: ComparisonSessionModule
    let export: ExportSessionModule
    let session: ImageToolsSessionModule
    let presets: PresetLibraryModule

    init() {
        let settings = PipelineSettingsModule()
        let assets = AssetCollectionModule()
        let rename = ExportRenameModule(settings: settings, assets: assets)
        let encodedOutput = EncodedOutputModule(settings: settings, assets: assets)
        let comparison = ComparisonSessionModule(
            settings: settings,
            assets: assets,
            encodedOutput: encodedOutput
        )
        let export = ExportSessionModule(
            settings: settings,
            assets: assets,
            rename: rename,
            encodedOutputCache: encodedOutput.cache
        )
        let session = ImageToolsSessionModule(
            settings: settings,
            assets: assets,
            encodedOutput: encodedOutput,
            comparison: comparison,
            export: export
        )
        let presets = PresetLibraryModule(settings: settings)

        self.settings = settings
        self.assets = assets
        self.rename = rename
        self.encodedOutput = encodedOutput
        self.comparison = comparison
        self.export = export
        self.session = session
        self.presets = presets
    }
}

extension View {
    @MainActor
    func imageToolsEnvironment(_ modules: ImageToolsModules) -> some View {
        self
            .environment(modules.settings)
            .environment(modules.assets)
            .environment(modules.rename)
            .environment(modules.encodedOutput)
            .environment(modules.comparison)
            .environment(modules.export)
            .environment(modules.session)
            .environment(modules.presets)
    }
}
