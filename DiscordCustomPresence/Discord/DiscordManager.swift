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

private func discordAuthFinished(
    _ success: Int32,
    _ message: UnsafePointer<CChar>?,
    _ refreshToken: UnsafePointer<CChar>?
) {
    let text: String

    if let message {
        text = String(cString: message)
    } else {
        text = "Unknown Discord authorization result."
    }

    print(
        "Discord OAuth:",
        success == 1 ? "SUCCESS" : "FAILED",
        text
    )

    if success == 1,
       let refreshToken {

        let token = String(
            cString: refreshToken
        )

        if KeychainStore.saveRefreshToken(token) {
            print(
                "Discord refresh token saved to Keychain."
            )
        } else {
            print(
                "Failed to save Discord refresh token."
            )
        }
    }
}


// MARK: - Status Callback

private func discordStatusChanged(
    _ status: DiscordBridgeStatus,
    _ context: UnsafeMutableRawPointer?
) {
    guard let context else {
        return
    }

    let manager = Unmanaged<DiscordManager>
        .fromOpaque(context)
        .takeUnretainedValue()

    Task { @MainActor in
        manager.handleDiscordStatus(status)
    }
}


// MARK: - User Callback

private let discordUserReceived:
    @convention(c) (
        UnsafePointer<CChar>?,
        UnsafePointer<CChar>?,
        UnsafePointer<CChar>?,
        UnsafeMutableRawPointer?
    ) -> Void = { displayName, username, avatarURL, context in

        guard let context else {
            return
        }

        let manager = Unmanaged<DiscordManager>
            .fromOpaque(context)
            .takeUnretainedValue()

        let displayNameString = displayName.map {
            String(cString: $0)
        }

        let usernameString = username.map {
            String(cString: $0)
        }

        let avatarURLString = avatarURL.map {
            String(cString: $0)
        }

        Task { @MainActor in
            manager.updateDiscordUser(
                displayName: displayNameString,
                username: usernameString,
                avatarURL: avatarURLString
            )
        }
    }


// MARK: - Discord Manager

@Observable
final class DiscordManager {

    // MARK: Properties

    var connectionState: DiscordConnectionState = .disconnected

    var username: String?
    var displayName: String?
    var avatarURL: URL?

    private var callbackTimer: Timer?

    private struct ActivePresence {
        let details: String
        let state: String
        let largeImage: String
        let largeImageText: String
        let smallImage: String
        let smallImageText: String
        let showElapsedTime: Bool
    }

    private var activePresence: ActivePresence?
    private var shouldRestorePresence = false

    var isAuthenticated: Bool {
        switch connectionState {
        case .connected, .discordUnavailable:
            return true

        default:
            return false
        }
    }


    // MARK: - Login With Token

    func restoreConnection() {
        guard let refreshToken =
            KeychainStore.loadRefreshToken()
        else {
            print(
                "No saved Discord login found."
            )
            return
        }

        print(
            "Saved Discord login found."
        )

        connectionState = .connecting

        startCallbackPump()

        let context = Unmanaged.passUnretained(self)
            .toOpaque()

        discord_bridge_set_status_callback(
            discordStatusChanged,
            context
        )

        discord_bridge_initialize(
            DiscordConfiguration.applicationID
        )

        refreshToken.withCString { tokenCString in
            discord_bridge_login_with_refresh_token(
                DiscordConfiguration.applicationID,
                tokenCString,
                discordAuthFinished
            )
        }
    }


    // MARK: - Connect

    func connect() {
        connectionState = .authorizing

        startCallbackPump()

        let context = Unmanaged.passUnretained(self)
            .toOpaque()

        discord_bridge_set_status_callback(
            discordStatusChanged,
            context
        )

        discord_bridge_initialize(
            DiscordConfiguration.applicationID
        )

        discord_bridge_authorize(
            DiscordConfiguration.applicationID,
            discordAuthFinished
        )

        print(
            "Discord OAuth started."
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
            connectionState = .disconnected

        case DiscordBridgeStatusConnecting:
            connectionState = .connecting

        case DiscordBridgeStatusReady:
            connectionState = .connected

            let context = Unmanaged.passUnretained(self)
                .toOpaque()

            discord_bridge_get_current_user(
                discordUserReceived,
                context
            )

            restoreActivePresenceIfNeeded()

        case DiscordBridgeStatusError:
            connectionState = .error(
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
        self.displayName = displayName
        self.username = username

        if let avatarURL {
            self.avatarURL = URL(
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
        showElapsedTime: Bool
    ) {
        let presence = ActivePresence(
            details: details,
            state: state,
            largeImage: largeImage,
            largeImageText: largeImageText,
            smallImage: smallImage,
            smallImageText: smallImageText,
            showElapsedTime: showElapsedTime
        )

        activePresence = presence
        shouldRestorePresence = true

        sendPresence(presence)
    }


    private func sendPresence(
        _ presence: ActivePresence
    ) {
        guard connectionState == .connected else {
            print(
                "Cannot update presence: Discord is not connected."
            )
            return
        }

        presence.details.withCString { detailsCString in
            presence.state.withCString { stateCString in
                presence.largeImage.withCString { largeImageCString in
                    presence.largeImageText.withCString { largeImageTextCString in
                        presence.smallImage.withCString { smallImageCString in
                            presence.smallImageText.withCString { smallImageTextCString in

                                discord_bridge_update_presence(
                                    detailsCString,
                                    stateCString,
                                    largeImageCString,
                                    largeImageTextCString,
                                    smallImageCString,
                                    smallImageTextCString,
                                    presence.showElapsedTime ? 1 : 0
                                )
                            }
                        }
                    }
                }
            }
        }
    }


    private func restoreActivePresenceIfNeeded() {
        guard shouldRestorePresence,
              let activePresence
        else {
            return
        }

        print(
            "Discord is ready. Restoring active Rich Presence..."
        )

        sendPresence(activePresence)
    }


    func clearPresence() {
        shouldRestorePresence = false
        activePresence = nil

        guard connectionState == .connected else {
            print(
                "Presence disabled while Discord is not connected."
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

        callbackTimer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { _ in
            discord_bridge_run_callbacks()
        }
    }


    // MARK: - Disconnect

    func disconnect() {
        clearPresence()

        KeychainStore.deleteRefreshToken()

        connectionState = .disconnected

        username = nil
        displayName = nil
        avatarURL = nil

        print(
            "Saved Discord login removed."
        )
    }
}
