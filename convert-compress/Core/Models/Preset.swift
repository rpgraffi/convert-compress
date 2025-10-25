import Foundation

struct Preset: Identifiable, Codable {
    let id: UUID
    var name: String?
    let createdAt: Date
    let configuration: ProcessingConfiguration
    
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return createdAt.formatted(date: .abbreviated, time: .shortened)
    }
    
    init(id: UUID = UUID(), name: String? = nil, createdAt: Date = Date(), configuration: ProcessingConfiguration) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.configuration = configuration
    }
}

