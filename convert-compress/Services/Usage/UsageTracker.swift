import Foundation

final class UsageTracker: ObservableObject {
    static let shared = UsageTracker()
    
    @Published private(set) var events: [UsageEventModel] = []
    
    private static let key = "image_tools.usage_events.v1"
    
    private init() {
        load()
    }
    
    func recordImageConversion() {
        events.append(.init(kind: .imageConversion, date: Date()))
        save()
    }
    
    func recordPipelineApplied() {
        events.append(.init(kind: .pipelineApplied, date: Date()))
        save()
    }
    
    var totalImageConversions: Int {
        events.filter { $0.kind == .imageConversion }.count
    }
    
    var totalPipelineApplications: Int {
        events.filter { $0.kind == .pipelineApplied }.count
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([UsageEventModel].self, from: data) else {
            return
        }
        events = decoded
    }
    
    private func save() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}


