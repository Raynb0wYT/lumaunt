#include "DiscordBridge.h"

#define DISCORDPP_IMPLEMENTATION
#include "discordpp.h"

#include <memory>
#include <cstdio>
#include <chrono>
#include <utility>


static std::shared_ptr<discordpp::Client> g_client = nullptr;

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
        [](auto status, auto error, auto errorDetail) {

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
                nullptr
            );
        }

        return;
    }


    printf(
        "[DiscordBridge] Starting OAuth...\n"
    );


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
            application_id,
            codeVerifier,
            callback
        ](
            discordpp::ClientResult result,
            std::string code,
            std::string redirectUri
        ) {

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
                        nullptr
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

                [callback](
                    discordpp::ClientResult tokenResult,
                    std::string accessToken,
                    std::string refreshToken,
                    discordpp::AuthorizationTokenType tokenType,
                    int32_t expiresIn,
                    std::string scopes
                ) {

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
                                nullptr
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
                            callback,
                            refreshToken
                        ](
                            discordpp::ClientResult updateResult
                        ) {

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
                                        nullptr
                                    );
                                }


                                return;
                            }


                            printf(
                                "[DiscordBridge] Token installed.\n"
                            );


                            // Pass the refresh token back to Swift.
                            // Swift will store it in Keychain.

                            if (callback != nullptr) {
                                callback(
                                    1,
                                    "Authorization successful.",
                                    refreshToken.c_str()
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


    g_client.reset();


    reportStatus(
        DiscordBridgeStatusDisconnected
    );
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
            discordpp::UserHandle::AvatarType::Gif,
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

void discord_bridge_update_presence(
    const char *details,
    const char *state,
    const char *large_image,
    const char *large_image_text,
    const char *small_image,
    const char *small_image_text,
    int show_elapsed_time
) {
    if (g_client == nullptr) {

        printf(
            "[DiscordBridge] Cannot update presence: "
            "client is not initialized.\n"
        );

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

    discordpp::ActivityAssets assets{};

    bool hasAssets = false;


    if (
        large_image != nullptr &&
        large_image[0] != '\0'
    ) {
        assets.SetLargeImage(
            std::string(large_image)
        );

        hasAssets = true;
    }


    if (
        large_image_text != nullptr &&
        large_image_text[0] != '\0'
    ) {
        assets.SetLargeText(
            std::string(large_image_text)
        );

        hasAssets = true;
    }


    if (
        small_image != nullptr &&
        small_image[0] != '\0'
    ) {
        assets.SetSmallImage(
            std::string(small_image)
        );

        hasAssets = true;
    }


    if (
        small_image_text != nullptr &&
        small_image_text[0] != '\0'
    ) {
        assets.SetSmallText(
            std::string(small_image_text)
        );

        hasAssets = true;
    }


    if (hasAssets) {
        activity.SetAssets(
            assets
        );
    }


    // MARK: Elapsed Time

    printf(
        "[DiscordBridge] show_elapsed_time = %d\n",
        show_elapsed_time
    );

    if (show_elapsed_time != 0) {

        discordpp::ActivityTimestamps timestamps{};


        auto now =
            std::chrono::system_clock::now();


        auto milliseconds =
            std::chrono::duration_cast<
                std::chrono::milliseconds
            >(
                now.time_since_epoch()
            ).count();


        timestamps.SetStart(
            static_cast<uint64_t>(
                milliseconds
            )
        );


        activity.SetTimestamps(
            timestamps
        );
    }


    // MARK: Send Activity

    printf(
        "[DiscordBridge] Updating Rich Presence...\n"
    );


    g_client->UpdateRichPresence(
        std::move(activity),

        [](
            discordpp::ClientResult result
        ) {

            if (result.Successful()) {

                printf(
                    "[DiscordBridge] Rich Presence updated successfully.\n"
                );

            } else {

                printf(
                    "[DiscordBridge] Rich Presence update failed: %s\n",
                    result.ToString().c_str()
                );
            }
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
                nullptr
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
                nullptr
            );
        }

        return;
    }

    printf(
        "[DiscordBridge] Refreshing Discord login...\n"
    );

    g_client->RefreshToken(
        application_id,
        std::string(refresh_token),
        [callback](
            discordpp::ClientResult result,
            std::string accessToken,
            std::string refreshToken,
            discordpp::AuthorizationTokenType tokenType,
            int32_t expiresIn,
            std::string scopes
        ) {
            if (!result.Successful()) {
                std::string error =
                    "Token refresh failed: " +
                    result.ToString();

                printf(
                    "[DiscordBridge] %s\n",
                    error.c_str()
                );

                if (callback != nullptr) {
                    callback(
                        0,
                        error.c_str(),
                        nullptr
                    );
                }

                return;
            }

            printf(
                "[DiscordBridge] Discord token refreshed.\n"
            );

            g_client->UpdateToken(
                tokenType,
                accessToken,
                [callback, refreshToken](
                    discordpp::ClientResult updateResult
                ) {
                    if (!updateResult.Successful()) {
                        std::string error =
                            "UpdateToken failed: " +
                            updateResult.ToString();

                        if (callback != nullptr) {
                            callback(
                                0,
                                error.c_str(),
                                nullptr
                            );
                        }

                        return;
                    }

                    // IMPORTANT:
                    // RefreshToken invalidates the old refresh token,
                    // so Swift must save this NEW one.

                    if (callback != nullptr) {
                        callback(
                            1,
                            "Saved Discord login restored.",
                            refreshToken.c_str()
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
