import Foundation
import Observation

@MainActor
@Observable
final class UsageTracker {
    static let shared = UsageTracker()

    private(set) var events: [UsageEventModel]

    @ObservationIgnored private let defaults: UserDefaults

    private static let eventsStorageKey = StorageKeys.Usage.events

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.events = Self.loadEvents(from: defaults)
    }

    var totalImageConversions: Int {
        countEvents(of: .imageConversion)
    }

    var totalPipelineApplications: Int {
        countEvents(of: .pipelineApplied)
    }

    func recordPipelineApplied(imageCount: Int) {
        guard imageCount > 0 else { return }

        let recordedAt = Date()
        let pipelineEvent = UsageEventModel(kind: .pipelineApplied, date: recordedAt)
        let conversionEvents = (0..<imageCount).map { _ in
            UsageEventModel(kind: .imageConversion, date: recordedAt)
        }

        events.append(pipelineEvent)
        events.append(contentsOf: conversionEvents)
        save()
    }

    private func countEvents(of kind: UsageEventModel.Kind) -> Int {
        events.filter { $0.kind == kind }.count
    }

    private static func loadEvents(from defaults: UserDefaults) -> [UsageEventModel] {
        guard let data = defaults.data(forKey: eventsStorageKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([UsageEventModel].self, from: data)
        } catch {
            AppLogger.usage.error("Failed to load usage events: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(events)
            defaults.set(data, forKey: Self.eventsStorageKey)
        } catch {
            AppLogger.usage.error("Failed to save usage events: \(error.localizedDescription, privacy: .public)")
        }
    }
}
