import Foundation
import Combine

extension ImageToolsViewModel {
    // Setup persistence state observation
    func setupPersistenceObservation() {
        // Observe exportDirectory changes
        $exportDirectory
            .dropFirst()
            .sink { [weak self] directory in
                guard let self else { return }
                self.persistExportDirectory()
                if let directory = directory {
                    SandboxAccessManager.shared.register(url: directory)
                }
            }
            .store(in: &cancellables)
        
        // Observe resizeMode changes
        $resizeMode
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                self.persistResizeMode()
            }
            .store(in: &cancellables)
        
        // Observe selectedFormat changes
        $selectedFormat
            .dropFirst()
            .sink { [weak self] newFormat in
                guard let self else { return }
                self.persistSelectedFormat()
                self.onSelectedFormatChanged(newFormat)
            }
            .store(in: &cancellables)
        
        // Observe recentFormats changes
        $recentFormats
            .dropFirst()
            .sink { [weak self] _ in
                self?.persistRecentFormats()
            }
            .store(in: &cancellables)
    }
    
    private enum PersistenceKeys {
        static let recentFormats = "image_tools.recent_formats.v1"
        static let selectedFormat = "image_tools.selected_format.v1"
        static let exportDirectory = "image_tools.export_directory.v1"
        static let resizeMode = "image_tools.resize_mode.v1"
    }

    func loadPersistedState() {
        let defaults = UserDefaults.standard

        if let raw = defaults.array(forKey: PersistenceKeys.recentFormats) as? [String] {
            let mapped = raw.compactMap { ImageIOCapabilities.shared.format(forIdentifier: $0) }
            if !mapped.isEmpty { recentFormats = Array(mapped.prefix(3)) }
        }

        if let selRaw = defaults.string(forKey: PersistenceKeys.selectedFormat),
           let fmt = ImageIOCapabilities.shared.format(forIdentifier: selRaw) {
            let caps = ImageIOCapabilities.shared
            if caps.supportsWriting(utType: fmt.utType) { selectedFormat = fmt }
        }

        if let exportPath = defaults.string(forKey: PersistenceKeys.exportDirectory) {
            exportDirectory = URL(fileURLWithPath: exportPath)
        }

        if let modeRaw = defaults.string(forKey: PersistenceKeys.resizeMode) {
            switch modeRaw {
            case "crop":
                resizeMode = .crop
            case "resize": fallthrough
            default:
                resizeMode = .resize
            }
        }

        // Re-run side effects that used to live in property observers
        if let directory = exportDirectory {
            SandboxAccessManager.shared.register(url: directory)
        }

        onSelectedFormatChanged(selectedFormat)
    }

    func persistRecentFormats() {
        let defaults = UserDefaults.standard
        defaults.set(recentFormats.map { $0.id }, forKey: PersistenceKeys.recentFormats)
    }

    func persistSelectedFormat() {
        let defaults = UserDefaults.standard
        defaults.set(selectedFormat?.id, forKey: PersistenceKeys.selectedFormat)
    }

    func persistExportDirectory() {
        let defaults = UserDefaults.standard
        if let dir = exportDirectory {
            defaults.set(dir.path, forKey: PersistenceKeys.exportDirectory)
        } else {
            defaults.removeObject(forKey: PersistenceKeys.exportDirectory)
        }
    }

    func persistResizeMode() {
        let defaults = UserDefaults.standard
        let value = (resizeMode == .resize) ? "crop" : "resize"
        defaults.set(value, forKey: PersistenceKeys.resizeMode)
    }
}


