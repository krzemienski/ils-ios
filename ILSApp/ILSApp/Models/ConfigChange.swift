import Foundation

struct ConfigChange: Identifiable, Codable {
    var id: UUID
    var timestamp: Date
    var source: ConfigSource
    var key: String
    var oldValue: String?
    var newValue: String
    var description: String

    enum ConfigSource: String, Codable, CaseIterable {
        case global = "Global"
        case user = "User"
        case project = "Project"

        var color: String {
            switch self {
            case .global: return "blue"
            case .user: return "orange"
            case .project: return "green"
            }
        }
    }

    init(id: UUID = UUID(), timestamp: Date = Date(), source: ConfigSource = .user, key: String = "", oldValue: String? = nil, newValue: String = "", description: String = "") {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.key = key
        self.oldValue = oldValue
        self.newValue = newValue
        self.description = description
    }
}
