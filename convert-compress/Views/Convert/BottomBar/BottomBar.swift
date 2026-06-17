import SwiftUI

struct BottomBar: View {
    @Environment(AssetCollectionModule.self) private var assets
    @Environment(ExportSessionModule.self) private var export
    
    var body: some View {
        @Bindable var export = export

        HStack(spacing: 8) {
            HStack(spacing: 8) {
                ClearControl()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            SaveControl()
            
            HStack(spacing: 8) {
                RenameControl()
                ExportDirectoryControl(
                    directory: $export.exportDirectory,
                    sourceDirectory: assets.sourceDirectory,
                    hasActiveImages: !assets.images.isEmpty
                )
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .animation(Theme.Animations.spring(), value: export.isExportingToSource)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}
