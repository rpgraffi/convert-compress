import Foundation
import SwiftUI

extension ImageToolsViewModel {
    // MARK: - Presets
    
    func loadPresets() {
        presets = PresetsStore.shared.load()
        
        // One-time migration: if load failed and returned empty, clear corrupted data
        if presets.isEmpty {
            // This will clear any old format data that failed to decode
            PresetsStore.shared.clearAll()
        }
    }
    
    // MARK: - Save Preset
    
    func savePreset(name: String?) {
        let preset = Preset(name: name, configuration: currentConfiguration)
        presets.append(preset)
        PresetsStore.shared.save(presets)
    }
    
    // MARK: - Apply Preset
    
    func applyPreset(_ preset: Preset) {
        let config = preset.configuration
        
        resizeMode = config.resizeMode
        resizeWidth = config.resizeWidth
        resizeHeight = config.resizeHeight
        resizeLongEdge = config.resizeLongEdge
        selectedFormat = config.selectedFormat
        compressionPercent = config.compressionPercent
        flipV = config.flipV
        removeMetadata = config.removeMetadata
        removeBackground = config.removeBackground
        
        if comparisonSelection != nil {
            scheduleComparisonPreviewRefresh()
        }
    }
    
    // MARK: - Update Preset
    
    func updatePreset(_ preset: Preset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index] = preset
        PresetsStore.shared.save(presets)
    }
    
    // MARK: - Delete Preset
    
    func deletePreset(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        PresetsStore.shared.save(presets)
    }
    
    // MARK: - Reorder Presets
    
    func reorderPresets(from source: Int, to destination: Int) {
        guard source != destination,
              source >= 0, source < presets.count,
              destination >= 0, destination < presets.count else {
            return
        }
        
        let preset = presets.remove(at: source)
        presets.insert(preset, at: destination)
        PresetsStore.shared.save(presets)
    }
}

