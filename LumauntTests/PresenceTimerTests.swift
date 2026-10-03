import Foundation
import XCTest
@testable import Lumaunt

@MainActor
final class PresenceTimerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testOrdinaryElapsedRestartsOnApply() throws {
        var presence = PresenceConfiguration()
        presence.startTimestamp = now.addingTimeInterval(-600)
        presence.endTimestamp = now.addingTimeInterval(600)
        try presence.applyTimer(at: now)
        XCTAssertEqual(presence.startTimestamp, now)
        XCTAssertNil(presence.endTimestamp)
    }

    func testCustomStartSurvivesRepeatedApplyAndRuntimeClearing() throws {
        var presence = PresenceConfiguration()
        let chosen = now.addingTimeInterval(-7_200)
        presence.customStartTime = chosen
        try presence.applyTimer(at: now)
        XCTAssertEqual(presence.startTimestamp, chosen)
        presence.startTimestamp = nil // Preset/draft/restore clears runtime values.
        try presence.applyTimer(at: now.addingTimeInterval(300))
        XCTAssertEqual(presence.startTimestamp, chosen)
    }

    func testCustomStartRoundTripsThroughSavedConfiguration() throws {
        var presence = PresenceConfiguration()
        presence.customStartTime = now.addingTimeInterval(-3_600)
        let data = try JSONEncoder().encode(presence)
        let restored = try JSONDecoder().decode(PresenceConfiguration.self, from: data)
        XCTAssertEqual(restored.customStartTime, presence.customStartTime)
    }

    func testOlderPresetsDefaultToStartOnApply() throws {
        var presence = try JSONDecoder().decode(PresenceConfiguration.self, from: Data("{\"details\":\"Gaming\"}".utf8))
        XCTAssertNil(presence.customStartTime)
        try presence.applyTimer(at: now)
        XCTAssertEqual(presence.startTimestamp, now)
    }

    func testInvalidDatesDoNotModifyRuntimeTimestamps() {
        for date in [now.addingTimeInterval(60), Date(timeIntervalSince1970: -1), Date(timeIntervalSince1970: .infinity)] {
            var presence = PresenceConfiguration()
            presence.customStartTime = date
            presence.startTimestamp = now
            XCTAssertThrowsError(try presence.applyTimer(at: now))
            XCTAssertEqual(presence.startTimestamp, now)
        }
    }

    func testCountdownIgnoresCustomElapsedStartAndRetainsRestoredDeadline() throws {
        var presence = PresenceConfiguration()
        presence.timerMode = .countdown
        presence.customStartTime = now.addingTimeInterval(-600)
        try presence.applyTimer(at: now)
        XCTAssertNil(presence.startTimestamp)
        XCTAssertEqual(presence.endTimestamp, now.addingTimeInterval(3_600))
        let deadline = now.addingTimeInterval(120)
        try presence.applyTimer(at: now, restoredExpiration: deadline)
        XCTAssertEqual(presence.endTimestamp, deadline)
    }
}
