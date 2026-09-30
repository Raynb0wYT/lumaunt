import Foundation

struct PresencePreset: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var configuration: PresenceConfiguration
}
