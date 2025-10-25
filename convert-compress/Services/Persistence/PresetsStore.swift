import Foundation

@MainActor
final class PresetsStore {
    static let shared = PresetsStore()
    
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private var storeKey: String {
        "\(Bundle.main.bundleIdentifier!).presets"
    }
    private var storeObserver: NSObjectProtocol?
    
    var onPresetsChanged: (() -> Void)?
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    
    private init() {
        startObservingUbiquitousStore()
    }
    
    deinit {
        if let observer = storeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public API
    
    func load() -> [Preset] {
        ubiquitousStore.synchronize()
        
        guard let data = ubiquitousStore.data(forKey: storeKey) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([Preset].self, from: data)
        } catch {
            print("Failed to decode presets: \(error)")
            return []
        }
    }
    
    func save(_ presets: [Preset]) {
        do {
            let data = try encoder.encode(presets)
            ubiquitousStore.set(data, forKey: storeKey)
            ubiquitousStore.synchronize()
        } catch {
            print("Failed to save presets: \(error)")
        }
    }
    
    func clearAll() {
        ubiquitousStore.removeObject(forKey: storeKey)
        ubiquitousStore.synchronize()
        onPresetsChanged?()
    }
    
    // MARK: - Private
    
    private func startObservingUbiquitousStore() {
        storeObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore,
            queue: nil
        ) { [weak self] notification in
            guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
                return
            }
            
            Task { @MainActor [weak self] in
                guard let self, changedKeys.contains(self.storeKey) else { return }
                self.ubiquitousStore.synchronize()
                self.onPresetsChanged?()
            }
        }
        
        ubiquitousStore.synchronize()
    }
}

