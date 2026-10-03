import Foundation
import Security

struct DiscordSession: Codable {
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiration: Date

    var needsRefresh: Bool {
        // Refresh if we're within 24 hours of expiration.
        accessTokenExpiration.timeIntervalSinceNow <= 86_400
    }
}

enum KeychainStore {

    private static let service =
        "com.Rayn.DiscordCustomPresence"

    private static let sessionAccount =
        "discord.session"

    // Keep this temporarily so we can remove credentials
    // saved by Lumaunt's old refresh-token-only system.
    private static let legacyRefreshTokenAccount =
        "discord.refreshToken"


    // MARK: - Discord Session

    static func saveDiscordSession(
        _ session: DiscordSession
    ) -> Bool {

        guard let data = try? JSONEncoder().encode(
            session
        ) else {
            print("Failed to encode Discord session.")
            return false
        }

        deleteItem(
            account: sessionAccount
        )

        let query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                service,

            kSecAttrAccount as String:
                sessionAccount,

            kSecValueData as String:
                data
        ]

        let status = SecItemAdd(
            query as CFDictionary,
            nil
        )

        if status == errSecSuccess {
            print("Discord session saved to Keychain.")
            return true
        }

        print(
            "Failed to save Discord session:",
            status
        )

        return false
    }


    static func loadDiscordSession()
        -> DiscordSession? {

        let query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                service,

            kSecAttrAccount as String:
                sessionAccount,

            kSecReturnData as String:
                true,

            kSecMatchLimit as String:
                kSecMatchLimitOne
        ]

        var result: CFTypeRef?

        let status = SecItemCopyMatching(
            query as CFDictionary,
            &result
        )

        guard status == errSecSuccess,
              let data = result as? Data
        else {
            return nil
        }

        do {
            return try JSONDecoder().decode(
                DiscordSession.self,
                from: data
            )
        } catch {
            print(
                "Failed to decode Discord session:",
                error
            )

            return nil
        }
    }


    static func deleteDiscordSession() {
        deleteItem(
            account: sessionAccount
        )

        print(
            "Discord session removed from Keychain."
        )
    }


    // MARK: - Legacy Token Cleanup

    static func deleteLegacyRefreshToken() {
        deleteItem(
            account: legacyRefreshTokenAccount
        )
    }


    // MARK: - Internal

    private static func deleteItem(
        account: String
    ) {

        let query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                service,

            kSecAttrAccount as String:
                account
        ]

        SecItemDelete(
            query as CFDictionary
        )
    }
}
