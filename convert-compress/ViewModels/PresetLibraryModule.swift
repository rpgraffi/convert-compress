import Foundation
import Observation

@MainActor
@Observable
final class PresetLibraryModule {
    private(set) var presets: [Preset] = []

    @ObservationIgnored private let settings: PipelineSettingsModule

    init(settings: PipelineSettingsModule) {
        self.settings = settings
        loadPresets()
    }

    func savePreset(name: String?) {
        let preset = Preset(name: name, configuration: settings.currentConfiguration)
        presets.append(preset)
        PresetsStore.shared.save(presets)
    }

    func applyPreset(_ preset: Preset) {
        settings.applyConfiguration(preset.configuration)
    }

    func updatePreset(_ preset: Preset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index] = preset
        PresetsStore.shared.save(presets)
    }

    func deletePreset(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        PresetsStore.shared.save(presets)
    }

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

    private func loadPresets() {
        presets = PresetsStore.shared.load()

        if presets.isEmpty {
            PresetsStore.shared.clearAll()
        }
    }
}
