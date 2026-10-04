#ifndef DiscordBridge_h
#define DiscordBridge_h

#include <stdint.h>


#ifdef __cplusplus
extern "C" {
#endif


// MARK: - Status

typedef enum {
    DiscordBridgeStatusDisconnected = 0,
    DiscordBridgeStatusConnecting = 1,
    DiscordBridgeStatusReady = 2,
    DiscordBridgeStatusError = 3
} DiscordBridgeStatus;


// MARK: - Status Callback

typedef void (*DiscordBridgeStatusCallback)(
    DiscordBridgeStatus status,
    void *context
);


// MARK: - Auth Callback

typedef void (*DiscordBridgeAuthCallback)(
    int success,
    const char *message,
    const char *access_token,
    const char *refresh_token,
    int64_t expires_in
);


// MARK: - User Callback

typedef void (*DiscordBridgeUserCallback)(
    const char *display_name,
    const char *username,
    const char *avatar_url,
    void *context
);


// MARK: - Presence Callback

typedef void (*DiscordBridgePresenceCallback)(
    int success,
    const char *message,
    void *context
);


// MARK: - Lifecycle

void discord_bridge_initialize(
    uint64_t application_id
);

void discord_bridge_run_callbacks(void);

void discord_bridge_shutdown(void);

// Changes on client creation and shutdown; used to reject queued stale callbacks.
uint64_t discord_bridge_connection_generation(void);


// MARK: - Current User

void discord_bridge_get_current_user(
    DiscordBridgeUserCallback callback,
    void *context
);


// MARK: - OAuth

void discord_bridge_authorize(
    uint64_t application_id,
    DiscordBridgeAuthCallback callback
);


// MARK: - Status

void discord_bridge_set_status_callback(
    DiscordBridgeStatusCallback callback,
    void *context
);


// MARK: - Rich Presence

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
);

void discord_bridge_clear_presence(void);


// MARK: - Saved Login

void discord_bridge_login_with_access_token(
    const char *access_token
);

void discord_bridge_login_with_refresh_token(
    uint64_t application_id,
    const char *refresh_token,
    DiscordBridgeAuthCallback callback
);


#ifdef __cplusplus
}
#endif

#endif
