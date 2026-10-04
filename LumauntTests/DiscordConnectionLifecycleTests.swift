import XCTest
@testable import Lumaunt

@MainActor
final class DiscordConnectionLifecycleTests: XCTestCase {
    // Exercise the installed SDK's client creation/destruction without OAuth,
    // Connect(), credentials, or a live Discord account.
    func testShutdownRejectsPreviousLifetimeAndAllowsFreshRuntime() {
        let manager = DiscordManager()
        manager.startConnectionRuntime()
        let oldGeneration = discord_bridge_connection_generation()
        XCTAssertTrue(manager.acceptsCallback(from: oldGeneration))

        manager.stopConnectionRuntime()
        XCTAssertFalse(manager.acceptsCallback(from: oldGeneration))
        XCTAssertEqual(manager.intentionalDisconnectGeneration, 1)

        manager.startConnectionRuntime()
        let newGeneration = discord_bridge_connection_generation()
        XCTAssertNotEqual(newGeneration, oldGeneration)
        XCTAssertFalse(manager.acceptsCallback(from: oldGeneration))
        XCTAssertTrue(manager.acceptsCallback(from: newGeneration))
        manager.stopConnectionRuntime()
    }

    func testPresenceCompletionIsReleasedExactlyOnceAcrossShutdownAndRestart() {
        let manager = DiscordManager()
        manager.startConnectionRuntime()
        let recorder = PresenceCompletionRecorder()
        let context = Unmanaged.passUnretained(recorder).toOpaque()
        // No connection is established. Whether the SDK rejects immediately or
        // queues its response, shutdown must complete this callback exactly once.
        discord_bridge_update_presence(
            "Lifecycle test", "", "", "", "", "", "", "", "", "",
            0, 0, recordPresenceCompletion, context
        )
        manager.stopConnectionRuntime()
        XCTAssertEqual(recorder.completions, 1)
        XCTAssertEqual(recorder.success, 0)
        manager.startConnectionRuntime()
        discord_bridge_run_callbacks() // Drain any old SDK result against a new client.
        XCTAssertEqual(recorder.completions, 1)
        manager.stopConnectionRuntime()
    }

    func testRepeatedShutdownIsSafeAndQueuedStatusCannotReopenRuntime() async {
        let manager = DiscordManager()
        manager.startConnectionRuntime() // Queues the initial SDK status callback.
        let generation = discord_bridge_connection_generation()
        manager.stopConnectionRuntime()
        manager.stopConnectionRuntime()
        await Task.yield() // Let queued Swift callback tasks run after shutdown.
        XCTAssertFalse(manager.acceptsCallback(from: generation))
        XCTAssertEqual(manager.connectionState, .disconnected)
        XCTAssertNil(manager.username)
        XCTAssertFalse(manager.hasActivePresence)
    }
}

private final class PresenceCompletionRecorder {
    var completions = 0
    var success: Int32?
}

private func recordPresenceCompletion(
    _ success: Int32,
    _ message: UnsafePointer<CChar>?,
    _ context: UnsafeMutableRawPointer?
) {
    guard let context else { return }
    let recorder = Unmanaged<PresenceCompletionRecorder>.fromOpaque(context).takeUnretainedValue()
    recorder.completions += 1
    recorder.success = success
}
