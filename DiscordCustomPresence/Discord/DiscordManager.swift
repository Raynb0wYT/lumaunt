import Foundation
import Observation


enum DiscordConnectionState: Equatable {
    case disconnected
    case authorizing
    case connecting
    case connected
    case discordUnavailable
    case error(String)
}


// MARK: - OAuth Callback

private weak var activeDiscordManager: DiscordManager?

private func discordAuthFinished(
    _ success: Int32,
    _ message: UnsafePointer<CChar>?,
    _ accessToken: UnsafePointer<CChar>?,
    _ refreshToken: UnsafePointer<CChar>?,
    _ expiresIn: Int64
) {
    let text: String

    if let message {
        text = String(cString: message)
    } else {
        text =
            "Unknown Discord authorization result."
    }

    print(
        "Discord OAuth:",
        success == 1
            ? "SUCCESS"
            : "FAILED",
        text
    )

    guard success == 1 else {
        Task { @MainActor in
            activeDiscordManager?
                .handleAuthenticationFailure(
                    message: text
                )
        }

        return
    }

    guard
        let accessToken,
        let refreshToken,
        expiresIn > 0
    else {
        print(
            "Discord authentication succeeded, " +
            "but the returned session was incomplete."
        )

        Task { @MainActor in
            activeDiscordManager?
                .handleAuthenticationFailure(
                    message:
                        "Discord returned an incomplete authentication session."
                )
        }

        return
    }

    let accessTokenString =
        String(cString: accessToken)

    let refreshTokenString =
        String(cString: refreshToken)

    let expiration =
        Date().addingTimeInterval(
            TimeInterval(expiresIn)
        )

    let session =
        DiscordSession(
            accessToken:
                accessTokenString,
            refreshToken:
                refreshTokenString,
            accessTokenExpiration:
                expiration
        )

    if KeychainStore
        .saveDiscordSession(session) {

        print(
            "Discord session credentials saved."
        )

        print(
            "Access token expires:",
            expiration
        )

    } else {
        print(
            "Failed to save Discord session."
        )
    }

    // Remove credentials created by Lumaunt's
    // old refresh-token-only implementation.
    KeychainStore
        .deleteLegacyRefreshToken()
}


// MARK: - Status Callback

private func discordStatusChanged(
    _ status: DiscordBridgeStatus,
    _ context: UnsafeMutableRawPointer?
) {
    guard let context else {
        return
    }

    let manager =
        Unmanaged<DiscordManager>
            .fromOpaque(context)
            .takeUnretainedValue()

    Task { @MainActor in
        manager.handleDiscordStatus(
            status
        )
    }
}


// MARK: - User Callback

private let discordUserReceived:
    @convention(c) (
        UnsafePointer<CChar>?,
        UnsafePointer<CChar>?,
        UnsafePointer<CChar>?,
        UnsafeMutableRawPointer?
    ) -> Void = {
        displayName,
        username,
        avatarURL,
        context in

        guard let context else {
            return
        }

        let manager =
            Unmanaged<DiscordManager>
                .fromOpaque(context)
                .takeUnretainedValue()

        let displayNameString =
            displayName.map {
                String(cString: $0)
            }

        let usernameString =
            username.map {
                String(cString: $0)
            }

        let avatarURLString =
            avatarURL.map {
                String(cString: $0)
            }

        Task { @MainActor in
            manager.updateDiscordUser(
                displayName:
                    displayNameString,
                username:
                    usernameString,
                avatarURL:
                    avatarURLString
            )
        }
    }


// MARK: - Presence Result

private struct PresenceUpdateError:
    LocalizedError {

    let message: String

    var errorDescription: String? {
        let trimmed =
            message.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if trimmed.isEmpty {
            return
                "Discord could not update your Rich Presence."
        }

        return
            "Discord could not update your Rich Presence: \(trimmed)"
    }
}


private struct PresenceUpdateTimeoutError:
    LocalizedError {

    var errorDescription: String? {
        "Discord did not respond to the presence update in time. Try again."
    }
}


// MARK: - Presence Continuation

private final class PresenceContinuationBox:
    @unchecked Sendable {

    private let lock = NSLock()

    private var continuation:
        CheckedContinuation<Void, Error>?

    private var finished = false

    init(
        continuation:
            CheckedContinuation<Void, Error>
    ) {
        self.continuation =
            continuation
    }


    func succeed() {
        finish(
            result: .success(())
        )
    }


    func fail(
        _ error: Error
    ) {
        finish(
            result: .failure(error)
        )
    }


    private func finish(
        result: Result<Void, Error>
    ) {
        let continuationToResume:
            CheckedContinuation<Void, Error>?

        lock.lock()

        if finished {
            continuationToResume = nil
        } else {
            finished = true

            continuationToResume =
                continuation

            continuation = nil
        }

        lock.unlock()

        guard let continuationToResume else {
            return
        }

        switch result {

        case .success:
            continuationToResume
                .resume()

        case .failure(let error):
            continuationToResume
                .resume(
                    throwing: error
                )
        }
    }
}


// MARK: - Presence Callback

private let discordPresenceFinished:
    @convention(c) (
        Int32,
        UnsafePointer<CChar>?,
        UnsafeMutableRawPointer?
    ) -> Void = {
        success,
        message,
        context in

        guard let context else {
            return
        }

        // This consumes the retain created when the
        // callback context was passed into the bridge.
        //
        // If Lumaunt already timed out, the box safely
        // ignores this late result while still allowing
        // the bridge-held retain to be released here.
        let box =
            Unmanaged<PresenceContinuationBox>
                .fromOpaque(context)
                .takeRetainedValue()

        let messageString =
            message.map {
                String(cString: $0)
            } ?? ""

        if success == 1 {
            box.succeed()
        } else {
            box.fail(
                PresenceUpdateError(
                    message:
                        messageString
                )
            )
        }
    }


// MARK: - Discord Manager

@Observable
final class DiscordManager {

    // MARK: Properties

    var connectionState:
        DiscordConnectionState =
        .disconnected

    var username: String?
    var displayName: String?
    var avatarURL: URL?

    private var callbackTimer: Timer?

    private let presenceUpdateTimeout:
        Duration = .seconds(15)


    private struct ActivePresence {
        let details: String
        let state: String

        let largeImage: String
        let largeImageText: String

        let smallImage: String
        let smallImageText: String

        let buttons:
            [PresenceButton]

        let startTimestamp: Date?
        let endTimestamp: Date?
    }


    private var activePresence:
        ActivePresence?

    private var shouldRestorePresence =
        false


    var hasActivePresence: Bool {
        shouldRestorePresence &&
        activePresence != nil
    }


    var activePresenceDetails: String? {
        guard let activePresence else {
            return nil
        }

        let details =
            activePresence.details
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return details.isEmpty
            ? nil
            : details
    }


    var activePresenceState: String? {
        guard let activePresence else {
            return nil
        }

        let state =
            activePresence.state
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return state.isEmpty
            ? nil
            : state
    }


    var isAuthenticated: Bool {
        switch connectionState {

        case .connected,
             .discordUnavailable:
            return true

        default:
            return false
        }
    }


    // MARK: - Restore Connection

    func restoreConnection() {
        activeDiscordManager = self

        guard
            let session =
                KeychainStore
                    .loadDiscordSession()
        else {
            print(
                "No saved Discord session found."
            )

            // Clean up credentials from the old
            // refresh-token-only implementation.
            KeychainStore
                .deleteLegacyRefreshToken()

            return
        }

        print(
            "Saved Discord session found."
        )

        connectionState =
            .connecting

        startCallbackPump()

        let context =
            Unmanaged
                .passUnretained(self)
                .toOpaque()

        discord_bridge_set_status_callback(
            discordStatusChanged,
            context
        )

        discord_bridge_initialize(
            DiscordConfiguration
                .applicationID
        )

        if session.needsRefresh {
            print(
                "Discord access token is near expiration. " +
                "Refreshing session..."
            )

            session.refreshToken
                .withCString {
                    refreshTokenCString in

                    discord_bridge_login_with_refresh_token(
                        DiscordConfiguration
                            .applicationID,
                        refreshTokenCString,
                        discordAuthFinished
                    )
                }

            return
        }

        print(
            "Discord access token is still valid. " +
            "Restoring without refresh..."
        )

        session.accessToken
            .withCString {
                accessTokenCString in

                discord_bridge_login_with_access_token(
                    accessTokenCString
                )
            }
    }


    // MARK: - Connect

    func connect() {
        activeDiscordManager = self

        connectionState =
            .authorizing

        startCallbackPump()

        let context =
            Unmanaged
                .passUnretained(self)
                .toOpaque()

        discord_bridge_set_status_callback(
            discordStatusChanged,
            context
        )

        discord_bridge_initialize(
            DiscordConfiguration
                .applicationID
        )

        discord_bridge_authorize(
            DiscordConfiguration
                .applicationID,
            discordAuthFinished
        )

        print(
            "Discord OAuth started."
        )
    }


    // MARK: - Authentication Failure

    @MainActor
    func handleAuthenticationFailure(
        message: String
    ) {
        print(
            "Discord authentication failed:",
            message
        )

        let normalizedMessage =
            message.lowercased()

        // invalid_grant means the saved OAuth
        // credentials can no longer restore
        // the Discord session.
        if normalizedMessage
            .contains("invalid_grant") {

            print(
                "Saved Discord session is invalid. " +
                "Clearing credentials."
            )

            KeychainStore
                .deleteDiscordSession()

            KeychainStore
                .deleteLegacyRefreshToken()

            connectionState =
                .disconnected

            username = nil
            displayName = nil
            avatarURL = nil

            return
        }

        connectionState =
            .error(
                "Discord authentication failed."
            )
    }


    // MARK: - Handle Discord Status

    @MainActor
    func handleDiscordStatus(
        _ status: DiscordBridgeStatus
    ) {
        print(
            "Discord bridge status changed:",
            status.rawValue
        )

        switch status {

        case DiscordBridgeStatusDisconnected:
            connectionState =
                .disconnected

        case DiscordBridgeStatusConnecting:
            connectionState =
                .connecting

        case DiscordBridgeStatusReady:
            connectionState =
                .connected

            let context =
                Unmanaged
                    .passUnretained(self)
                    .toOpaque()

            discord_bridge_get_current_user(
                discordUserReceived,
                context
            )

            restoreActivePresenceIfNeeded()

        case DiscordBridgeStatusError:
            connectionState =
                .error(
                    "Discord connection failed."
                )

        default:
            break
        }
    }


    // MARK: - Update Discord User

    @MainActor
    func updateDiscordUser(
        displayName: String?,
        username: String?,
        avatarURL: String?
    ) {
        self.displayName =
            displayName

        self.username =
            username

        if let avatarURL {
            self.avatarURL =
                URL(
                    string: avatarURL
                )
        } else {
            self.avatarURL = nil
        }

        print(
            "Discord user loaded:",
            displayName ?? "Unknown",
            username ?? "Unknown"
        )
    }


    // MARK: - Rich Presence

    func updatePresence(
        details: String,
        state: String,
        largeImage: String,
        largeImageText: String,
        smallImage: String,
        smallImageText: String,
        buttons: [PresenceButton],
        startTimestamp: Date?,
        endTimestamp: Date?
    ) async throws {

        let presence =
            ActivePresence(
                details: details,
                state: state,
                largeImage: largeImage,
                largeImageText:
                    largeImageText,
                smallImage: smallImage,
                smallImageText:
                    smallImageText,
                buttons: buttons,
                startTimestamp:
                    startTimestamp,
                endTimestamp:
                    endTimestamp
            )

        guard
            connectionState ==
                .connected
        else {
            throw PresenceUpdateError(
                message:
                    "Discord is not connected."
            )
        }

        try await sendPresence(
            presence
        )

        // Only remember the presence after Discord's
        // UpdateRichPresence callback reports success.
        activePresence = presence
        shouldRestorePresence = true
    }


    // MARK: - Send Presence

    private func sendPresence(
        _ presence: ActivePresence
    ) async throws {

        guard
            connectionState ==
                .connected
        else {
            throw PresenceUpdateError(
                message:
                    "Discord is not connected."
            )
        }


        // MARK: Timer Timestamps

        let startTimestampMilliseconds:
            Int64

        if let startTimestamp =
            presence.startTimestamp {

            startTimestampMilliseconds =
                Int64(
                    startTimestamp
                        .timeIntervalSince1970 *
                    1000
                )

        } else {
            startTimestampMilliseconds =
                0
        }


        let endTimestampMilliseconds:
            Int64

        if let endTimestamp =
            presence.endTimestamp {

            endTimestampMilliseconds =
                Int64(
                    endTimestamp
                        .timeIntervalSince1970 *
                    1000
                )

        } else {
            endTimestampMilliseconds =
                0
        }


        // MARK: Buttons

        let button1 =
            presence.buttons.indices
                .contains(0)
                ? presence.buttons[0]
                : PresenceButton()

        let button2 =
            presence.buttons.indices
                .contains(1)
                ? presence.buttons[1]
                : PresenceButton()


        // MARK: Await Bridge Result

        try await withCheckedThrowingContinuation {
            (
                continuation:
                    CheckedContinuation<
                        Void,
                        Error
                    >
            ) in

            let box =
                PresenceContinuationBox(
                    continuation:
                        continuation
                )

            // The bridge callback owns one retain.
            //
            // It is intentionally NOT released by the
            // timeout path because Discord may legally
            // invoke the callback later. Releasing it
            // early would leave the C callback holding
            // a dangling pointer.
            let context =
                Unmanaged
                    .passRetained(box)
                    .toOpaque()


            // Start the timeout independently of the
            // bridge operation.
            //
            // The continuation box guarantees that only
            // the first result -- callback or timeout --
            // can resume the Swift continuation.
            Task { [box, presenceUpdateTimeout] in
                do {
                    try await Task.sleep(
                        for:
                            presenceUpdateTimeout
                    )
                } catch {
                    return
                }

                box.fail(
                    PresenceUpdateTimeoutError()
                )
            }


            presence.details
                .withCString {
                    detailsCString in

                    presence.state
                        .withCString {
                            stateCString in

                            presence.largeImage
                                .withCString {
                                    largeImageCString in

                                    presence.largeImageText
                                        .withCString {
                                            largeImageTextCString in

                                            presence.smallImage
                                                .withCString {
                                                    smallImageCString in

                                                    presence.smallImageText
                                                        .withCString {
                                                            smallImageTextCString in

                                                            button1.label
                                                                .withCString {
                                                                    button1LabelCString in

                                                                    button1.url
                                                                        .withCString {
                                                                            button1URLCString in

                                                                            button2.label
                                                                                .withCString {
                                                                                    button2LabelCString in

                                                                                    button2.url
                                                                                        .withCString {
                                                                                            button2URLCString in

                                                                                            discord_bridge_update_presence(
                                                                                                detailsCString,
                                                                                                stateCString,
                                                                                                largeImageCString,
                                                                                                largeImageTextCString,
                                                                                                smallImageCString,
                                                                                                smallImageTextCString,
                                                                                                button1LabelCString,
                                                                                                button1URLCString,
                                                                                                button2LabelCString,
                                                                                                button2URLCString,
                                                                                                startTimestampMilliseconds,
                                                                                                endTimestampMilliseconds,
                                                                                                discordPresenceFinished,
                                                                                                context
                                                                                            )
                                                                                        }
                                                                                }
                                                                        }
                                                                }
                                                        }
                                                }
                                        }
                                }
                        }
                }
        }
    }


    // MARK: - Restore Active Presence

    private func restoreActivePresenceIfNeeded() {
        guard
            shouldRestorePresence,
            let activePresence
        else {
            return
        }

        print(
            "Discord is ready. " +
            "Restoring active Rich Presence..."
        )

        Task {
            do {
                try await sendPresence(
                    activePresence
                )

                print(
                    "Active Rich Presence restored."
                )

            } catch {
                print(
                    "Failed to restore active Rich Presence:",
                    error.localizedDescription
                )
            }
        }
    }


    // MARK: - Clear Presence

    func clearPresence() {
        shouldRestorePresence = false
        activePresence = nil

        guard
            connectionState ==
                .connected
        else {
            print(
                "Presence disabled while Discord " +
                "is not connected."
            )

            return
        }

        discord_bridge_clear_presence()

        print(
            "Active Rich Presence disabled."
        )
    }


    // MARK: - Callback Pump

    private func startCallbackPump() {
        guard callbackTimer == nil else {
            return
        }

        callbackTimer =
            Timer.scheduledTimer(
                withTimeInterval: 0.1,
                repeats: true
            ) { _ in
                discord_bridge_run_callbacks()
            }
    }


    // MARK: - Disconnect

    func disconnect() {
        clearPresence()

        KeychainStore
            .deleteDiscordSession()

        KeychainStore
            .deleteLegacyRefreshToken()

        connectionState =
            .disconnected

        username = nil
        displayName = nil
        avatarURL = nil

        print(
            "Saved Discord login removed."
        )
    }
}
