import Foundation

struct PresenceConfiguration: Codable, Equatable {

    var details: String = ""
    var state: String = ""

    var largeImage: String = ""
    var largeImageText: String = ""

    var smallImage: String = ""
    var smallImageText: String = ""

    var showElapsedTime: Bool = false
    var startTimestamp: Date?

    var buttons: [PresenceButton] = []
}

struct PresenceButton: Codable, Equatable, Identifiable {
    var id = UUID()
    var label: String = ""
    var url: String = ""
}
