import Foundation

@MainActor
final class PresetsStore {
    static let shared = PresetsStore()
    
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private var storeKey: String {
        "\(Bundle.main.bundleIdentifier!).presets"
    }
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    
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
    }
}

