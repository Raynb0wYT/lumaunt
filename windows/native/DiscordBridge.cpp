#include "DiscordBridge.h"

#define DISCORDPP_IMPLEMENTATION
#include "discordpp.h"
#include "PresenceArtwork.h"

#include <memory>
#include <cstdio>
#include <chrono>
#include <utility>
#include <vector>
#include <algorithm>


static std::shared_ptr<discordpp::Client> g_client = nullptr;

// Every asynchronous operation belongs to one client lifetime.
static uint64_t g_generation = 0;
uint64_t discord_bridge_connection_generation(void) { return g_generation; }
static bool isCurrentClient(uint64_t generation) {
    return g_client != nullptr && generation == g_generation;
}

struct PendingPresence {
    DiscordBridgePresenceCallback callback;
    void *context;
    void finish(int success, const char *message) {
        auto completion = std::exchange(callback, nullptr);
        if (completion) completion(success, message, context);
    }
};
static std::vector<std::shared_ptr<PendingPresence>> g_pendingPresence;

static DiscordBridgeStatusCallback g_statusCallback = nullptr;

static void *g_statusContext = nullptr;


// MARK: - Status Reporting

static void reportStatus(
    DiscordBridgeStatus status
) {
    if (g_statusCallback != nullptr) {
        g_statusCallback(
            status,
            g_statusContext
        );
    }
}


void discord_bridge_set_status_callback(
    DiscordBridgeStatusCallback callback,
    void *context
) {
    g_statusCallback = callback;
    g_statusContext = context;
}


// MARK: - Initialize

void discord_bridge_initialize(
    uint64_t application_id
) {
    if (g_client != nullptr) {
        return;
    }

    printf(
        "[DiscordBridge] Creating Discord client...\n"
    );

    const auto generation = ++g_generation;

    g_client =
        std::make_shared<discordpp::Client>();

    g_client->SetApplicationId(
        application_id
    );


    // MARK: Logging

    g_client->AddLogCallback(
        [](auto message, auto severity) {
            printf(
                "[Discord SDK] [%d] %s\n",
                static_cast<int>(severity),
                message.c_str()
            );
        },
        discordpp::LoggingSeverity::Info
    );


    // MARK: Status Changes

    g_client->SetStatusChangedCallback(
        [generation](auto status, auto error, auto errorDetail) {
            if (!isCurrentClient(generation)) return;

            printf(
                "[DiscordBridge] SDK status: %s\n",
                discordpp::Client::StatusToString(
                    status
                ).c_str()
            );

            if (
                status ==
                discordpp::Client::Status::Ready
            ) {
                reportStatus(
                    DiscordBridgeStatusReady
                );
            }
        }
    );


    reportStatus(
        DiscordBridgeStatusDisconnected
    );


    printf(
        "[DiscordBridge] Client created for application %llu\n",
        application_id
    );
}


// MARK: - OAuth Authorization

void discord_bridge_authorize(
    uint64_t application_id,
    DiscordBridgeAuthCallback callback
) {
    if (g_client == nullptr) {
        if (callback != nullptr) {
            callback(
                0,
                "Discord client is not initialized.",
                nullptr,
                nullptr,
                0
            );
        }

        return;
    }

    printf(
        "[DiscordBridge] Starting OAuth...\n"
    );

    const auto generation = g_generation;

    auto verifier =
        g_client->CreateAuthorizationCodeVerifier();

    discordpp::AuthorizationArgs args;

    args.SetClientId(
        application_id
    );

    args.SetScopes(
        discordpp::Client::GetDefaultPresenceScopes()
    );

    args.SetCodeChallenge(
        verifier.Challenge()
    );

    std::string codeVerifier =
        verifier.Verifier();

    g_client->Authorize(
        args,

        [
            generation,
            application_id,
            codeVerifier,
            callback
        ](
            discordpp::ClientResult result,
            std::string code,
            std::string redirectUri
        ) {
            if (!isCurrentClient(generation)) return;

            // MARK: Authorization Result

            if (!result.Successful()) {
                std::string error =
                    "Authorization failed: "
                    + result.ToString();

                printf(
                    "[DiscordBridge] %s\n",
                    error.c_str()
                );

                if (callback != nullptr) {
                    callback(
                        0,
                        error.c_str(),
                        nullptr,
                        nullptr,
                        0
                    );
                }

                return;
            }

            printf(
                "[DiscordBridge] Authorization code received.\n"
            );

            // MARK: Exchange Code For Tokens

            g_client->GetToken(
                application_id,
                code,
                codeVerifier,
                redirectUri,

                [callback, generation](
                    discordpp::ClientResult tokenResult,
                    std::string accessToken,
                    std::string refreshToken,
                    discordpp::AuthorizationTokenType tokenType,
                    int32_t expiresIn,
                    std::string scopes
                ) {
                    if (!isCurrentClient(generation)) return;

                    if (!tokenResult.Successful()) {
                        std::string error =
                            "Token exchange failed: "
                            + tokenResult.ToString();

                        printf(
                            "[DiscordBridge] %s\n",
                            error.c_str()
                        );

                        if (callback != nullptr) {
                            callback(
                                0,
                                error.c_str(),
                                nullptr,
                                nullptr,
                                0
                            );
                        }

                        return;
                    }

                    printf(
                        "[DiscordBridge] Access token received.\n"
                    );

                    // MARK: Install Access Token

                    g_client->UpdateToken(
                        tokenType,
                        accessToken,

                        [
                            generation,
                            callback,
                            accessToken,
                            refreshToken,
                            expiresIn
                        ](
                            discordpp::ClientResult updateResult
                        ) {
                            if (!isCurrentClient(generation)) return;

                            if (!updateResult.Successful()) {
                                std::string error =
                                    "UpdateToken failed: "
                                    + updateResult.ToString();

                                printf(
                                    "[DiscordBridge] %s\n",
                                    error.c_str()
                                );

                                if (callback != nullptr) {
                                    callback(
                                        0,
                                        error.c_str(),
                                        nullptr,
                                        nullptr,
                                        0
                                    );
                                }

                                return;
                            }

                            printf(
                                "[DiscordBridge] Token installed.\n"
                            );

                            if (callback != nullptr) {
                                callback(
                                    1,
                                    "Authorization successful.",
                                    accessToken.c_str(),
                                    refreshToken.c_str(),
                                    static_cast<int64_t>(expiresIn)
                                );
                            }

                            reportStatus(
                                DiscordBridgeStatusConnecting
                            );

                            g_client->Connect();
                        }
                    );
                }
            );
        }
    );
}
// MARK: - Run SDK Callbacks

void discord_bridge_run_callbacks(
    void
) {
    discordpp::RunCallbacks();
}


// MARK: - Shutdown

void discord_bridge_shutdown(
    void
) {
    printf(
        "[DiscordBridge] Shutting down.\n"
    );


    // Invalidate callbacks before aborting SDK operations (which may complete inline).
    ++g_generation;
    g_statusCallback = nullptr;
    g_statusContext = nullptr;
    for (auto &pending : g_pendingPresence) {
        pending->finish(0, "Discord account disconnected.");
    }
    g_pendingPresence.clear();
    if (g_client) {
        g_client->AbortAuthorize();
        g_client->Disconnect();
        // Client destruction calls the installed SDK's Client::Drop.
        g_client.reset();
    }
}


// MARK: - Current Discord User

void discord_bridge_get_current_user(
    DiscordBridgeUserCallback callback,
    void *context
) {
    if (
        g_client == nullptr ||
        callback == nullptr
    ) {
        return;
    }


    auto user =
        g_client->GetCurrentUserV2();


    if (!user.has_value()) {
        printf(
            "[DiscordBridge] Current user is not available.\n"
        );

        return;
    }


    std::string displayName =
        user->DisplayName();


    std::string username =
        user->Username();


    std::string avatarUrl =
        user->AvatarUrl(
            discordpp::UserHandle::AvatarType::Png,
            discordpp::UserHandle::AvatarType::Png
        );


    printf(
        "[DiscordBridge] Current user: %s (@%s)\n",
        displayName.c_str(),
        username.c_str()
    );


    callback(
        displayName.c_str(),
        username.c_str(),
        avatarUrl.c_str(),
        context
    );
}


// MARK: - Update Rich Presence

// MARK: - Update Rich Presence

void discord_bridge_update_presence(
    const char *details,
    const char *state,
    const char *large_image,
    const char *large_image_text,
    const char *small_image,
    const char *small_image_text,
    const char *button_1_label,
    const char *button_1_url,
    const char *button_2_label,
    const char *button_2_url,
    int64_t start_timestamp,
    int64_t end_timestamp,
    DiscordBridgePresenceCallback callback,
    void *context
) {
    if (g_client == nullptr) {

        const char *message =
            "Discord client is not initialized.";

        printf(
            "[DiscordBridge] Cannot update presence: %s\n",
            message
        );

        if (callback != nullptr) {
            callback(
                0,
                message,
                context
            );
        }

        return;
    }


    discordpp::Activity activity{};


    // MARK: Details

    if (
        details != nullptr &&
        details[0] != '\0'
    ) {
        activity.SetDetails(
            std::string(details)
        );
    }


    // MARK: State

    if (
        state != nullptr &&
        state[0] != '\0'
    ) {
        activity.SetState(
            std::string(state)
        );
    }


    // MARK: Images

    setPresenceArtwork(activity, large_image, large_image_text, small_image, small_image_text);


    // MARK: Timer

    discordpp::ActivityTimestamps timestamps{};

    bool hasTimestamp = false;


    if (start_timestamp > 0) {

        timestamps.SetStart(
            static_cast<uint64_t>(
                start_timestamp
            )
        );

        hasTimestamp = true;

        printf(
            "[DiscordBridge] Elapsed timer start: %lld\n",
            static_cast<long long>(
                start_timestamp
            )
        );
    }


    if (end_timestamp > 0) {

        timestamps.SetEnd(
            static_cast<uint64_t>(
                end_timestamp
            )
        );

        hasTimestamp = true;

        printf(
            "[DiscordBridge] Countdown timer end: %lld\n",
            static_cast<long long>(
                end_timestamp
            )
        );
    }


    if (hasTimestamp) {
        activity.SetTimestamps(
            timestamps
        );
    }


    // MARK: Buttons

    if (
        button_1_label != nullptr &&
        button_1_label[0] != '\0' &&
        button_1_url != nullptr &&
        button_1_url[0] != '\0'
    ) {
        discordpp::ActivityButton button{};

        button.SetLabel(
            std::string(button_1_label)
        );

        button.SetUrl(
            std::string(button_1_url)
        );

        activity.AddButton(
            button
        );
    }


    if (
        button_2_label != nullptr &&
        button_2_label[0] != '\0' &&
        button_2_url != nullptr &&
        button_2_url[0] != '\0'
    ) {
        discordpp::ActivityButton button{};

        button.SetLabel(
            std::string(button_2_label)
        );

        button.SetUrl(
            std::string(button_2_url)
        );

        activity.AddButton(
            button
        );
    }


    // MARK: Send Activity

    printf(
        "[DiscordBridge] Updating Rich Presence...\n"
    );


    g_pendingPresence.erase(
        std::remove_if(g_pendingPresence.begin(), g_pendingPresence.end(),
                       [](const auto &pending) { return pending->callback == nullptr; }),
        g_pendingPresence.end());
    auto pending = std::make_shared<PendingPresence>(PendingPresence{callback, context});
    g_pendingPresence.push_back(pending);
    const auto generation = g_generation;
    g_client->UpdateRichPresence(
        std::move(activity),
        [pending, generation](discordpp::ClientResult result) {
            if (!isCurrentClient(generation)) return;
            const auto message = result.ToString();
            pending->finish(result.Successful() ? 1 : 0, message.c_str());
        }
    );
}

// MARK: - Clear Rich Presence

void discord_bridge_clear_presence(
    void
) {
    if (g_client == nullptr) {

        printf(
            "[DiscordBridge] Cannot clear presence: "
            "client is not initialized.\n"
        );

        return;
    }


    printf(
        "[DiscordBridge] Clearing Rich Presence...\n"
    );


    g_client->ClearRichPresence();


    printf(
        "[DiscordBridge] Rich Presence cleared.\n"
    );
}

// MARK: Login With Refresh Token

void discord_bridge_login_with_refresh_token(
    uint64_t application_id,
    const char *refresh_token,
    DiscordBridgeAuthCallback callback
) {
    if (g_client == nullptr) {
        if (callback != nullptr) {
            callback(
                0,
                "Discord client is not initialized.",
                nullptr,
                nullptr,
                0
            );
        }

        return;
    }

    if (refresh_token == nullptr ||
        refresh_token[0] == '\0') {

        if (callback != nullptr) {
            callback(
                0,
                "Refresh token is empty.",
                nullptr,
                nullptr,
                0
            );
        }

        return;
    }

    printf(
        "[DiscordBridge] Refreshing Discord login...\n"
    );

    const auto generation = g_generation;

    g_client->RefreshToken(
        application_id,
        std::string(refresh_token),

        [callback, generation](
            discordpp::ClientResult result,
            std::string accessToken,
            std::string refreshToken,
            discordpp::AuthorizationTokenType tokenType,
            int32_t expiresIn,
            std::string scopes
        ) {
            if (!isCurrentClient(generation)) return;

            if (!result.Successful()) {
                std::string error =
                    "Token refresh failed: "
                    + result.ToString();

                printf(
                    "[DiscordBridge] %s\n",
                    error.c_str()
                );

                if (callback != nullptr) {
                    callback(
                        0,
                        error.c_str(),
                        nullptr,
                        nullptr,
                        0
                    );
                }

                return;
            }

            printf(
                "[DiscordBridge] Discord token refreshed.\n"
            );

            // MARK: Install New Access Token

            g_client->UpdateToken(
                tokenType,
                accessToken,

                [
                    generation,
                    callback,
                    accessToken,
                    refreshToken,
                    expiresIn
                ](
                    discordpp::ClientResult updateResult
                ) {
                    if (!isCurrentClient(generation)) return;

                    if (!updateResult.Successful()) {
                        std::string error =
                            "UpdateToken failed: "
                            + updateResult.ToString();

                        printf(
                            "[DiscordBridge] %s\n",
                            error.c_str()
                        );

                        if (callback != nullptr) {
                            callback(
                                0,
                                error.c_str(),
                                nullptr,
                                nullptr,
                                0
                            );
                        }

                        return;
                    }

                    printf(
                        "[DiscordBridge] Refreshed token installed.\n"
                    );

                    // RefreshToken rotates the credentials.
                    // Swift must persist BOTH replacements.

                    if (callback != nullptr) {
                        callback(
                            1,
                            "Saved Discord login refreshed.",
                            accessToken.c_str(),
                            refreshToken.c_str(),
                            static_cast<int64_t>(expiresIn)
                        );
                    }

                    reportStatus(
                        DiscordBridgeStatusConnecting
                    );

                    g_client->Connect();
                }
            );
        }
    );
}

void discord_bridge_login_with_access_token(
    const char *access_token
) {
    if (g_client == nullptr) {
        printf(
            "[DiscordBridge] Cannot restore access token: "
            "client is not initialized.\n"
        );

        return;
    }

    if (access_token == nullptr ||
        access_token[0] == '\0') {

        printf(
            "[DiscordBridge] Cannot restore access token: "
            "token is empty.\n"
        );

        return;
    }

    printf(
        "[DiscordBridge] Installing saved access token...\n"
    );

    const auto generation = g_generation;

    g_client->UpdateToken(
        discordpp::AuthorizationTokenType::Bearer,
        std::string(access_token),

        [generation](
            discordpp::ClientResult result
        ) {
            if (!isCurrentClient(generation)) return;
            if (!result.Successful()) {
                printf(
                    "[DiscordBridge] Saved access token failed: %s\n",
                    result.ToString().c_str()
                );

                reportStatus(
                    DiscordBridgeStatusError
                );

                return;
            }

            printf(
                "[DiscordBridge] Saved access token installed.\n"
            );

            reportStatus(
                DiscordBridgeStatusConnecting
            );

            g_client->Connect();
        }
    );
}
