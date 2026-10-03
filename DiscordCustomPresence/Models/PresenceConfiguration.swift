import Foundation

enum PresenceTimerMode: String, Codable, CaseIterable {
    case elapsed
    case countdown

    var title: String {
        switch self {
        case .elapsed:
            return "Elapsed Time"
        case .countdown:
            return "Countdown"
        }
    }
}

struct PresenceConfiguration: Codable, Equatable {

    var details: String = ""
    var state: String = ""

    var largeImage: String = ""
    var largeImageText: String = ""

    var smallImage: String = ""
    var smallImageText: String = ""

    var timerMode: PresenceTimerMode = .elapsed

    // A saved user choice, separate from the applied runtime timestamp.
    // Nil preserves the original start-on-Apply behavior.
    var customStartTime: Date?

    // Used when timerMode == .countdown.
    // Default: 1 hour.
    var countdownDuration: TimeInterval = 3600

    // When enabled, the applied presence is cleared when its
    // countdown reaches the end timestamp.
    var disablePresenceWhenTimerEnds = false

    // Runtime timer values.
    var startTimestamp: Date?
    var endTimestamp: Date?

    var buttons: [PresenceButton] = []

    func hasValidCustomStartTime(at now: Date) -> Bool {
        guard let customStartTime else { return true }
        return customStartTime.timeIntervalSince1970.isFinite &&
            customStartTime >= Date(timeIntervalSince1970: 0) &&
            customStartTime <= now
    }

    mutating func applyTimer(at now: Date, restoredExpiration: Date? = nil) throws {
        switch timerMode {
        case .elapsed:
            guard hasValidCustomStartTime(at: now) else {
                throw PresenceTimerError.invalidStartTime
            }
            startTimestamp = customStartTime ?? now
            endTimestamp = nil
        case .countdown:
            startTimestamp = nil
            endTimestamp = restoredExpiration ?? now.addingTimeInterval(countdownDuration)
        }
    }


    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case details
        case state
        case largeImage
        case largeImageText
        case smallImage
        case smallImageText
        case timerMode
        case customStartTime
        case countdownDuration
        case disablePresenceWhenTimerEnds
        case startTimestamp
        case endTimestamp
        case buttons
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        details = try container.decodeIfPresent(
            String.self,
            forKey: .details
        ) ?? ""

        state = try container.decodeIfPresent(
            String.self,
            forKey: .state
        ) ?? ""

        largeImage = try container.decodeIfPresent(
            String.self,
            forKey: .largeImage
        ) ?? ""

        largeImageText = try container.decodeIfPresent(
            String.self,
            forKey: .largeImageText
        ) ?? ""

        smallImage = try container.decodeIfPresent(
            String.self,
            forKey: .smallImage
        ) ?? ""

        smallImageText = try container.decodeIfPresent(
            String.self,
            forKey: .smallImageText
        ) ?? ""

        timerMode = try container.decodeIfPresent(
            PresenceTimerMode.self,
            forKey: .timerMode
        ) ?? .elapsed

        customStartTime = try container.decodeIfPresent(Date.self, forKey: .customStartTime)

        countdownDuration = try container.decodeIfPresent(
            TimeInterval.self,
            forKey: .countdownDuration
        ) ?? 3600

        disablePresenceWhenTimerEnds = try container.decodeIfPresent(
            Bool.self,
            forKey: .disablePresenceWhenTimerEnds
        ) ?? false

        startTimestamp = try container.decodeIfPresent(
            Date.self,
            forKey: .startTimestamp
        )

        endTimestamp = try container.decodeIfPresent(
            Date.self,
            forKey: .endTimestamp
        )

        buttons = try container.decodeIfPresent(
            [PresenceButton].self,
            forKey: .buttons
        ) ?? []
    }
}

enum PresenceTimerError: LocalizedError {
    case invalidStartTime

    var errorDescription: String? {
        "Choose a start time between January 1, 1970 and now."
    }
}

struct PresenceButton: Codable, Equatable, Identifiable {
    var id = UUID()
    var label: String = ""
    var url: String = ""
}
