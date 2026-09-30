#ifndef DiscordBridge_h
#define DiscordBridge_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    DiscordBridgeStatusDisconnected = 0,
    DiscordBridgeStatusConnecting = 1,
    DiscordBridgeStatusReady = 2,
    DiscordBridgeStatusError = 3
} DiscordBridgeStatus;

typedef void (*DiscordBridgeStatusCallback)(
    DiscordBridgeStatus status,
    void *context
);

typedef void (*DiscordBridgeAuthCallback)(
    int success,
    const char *message,
    const char *refresh_token
);

typedef void (*DiscordBridgeUserCallback)(
    const char *display_name,
    const char *username,
    const char *avatar_url,
    void *context
);


void discord_bridge_initialize(uint64_t application_id);
void discord_bridge_run_callbacks(void);
void discord_bridge_shutdown(void);
void discord_bridge_get_current_user(
    DiscordBridgeUserCallback callback,
    void *context
);

void discord_bridge_authorize(
    uint64_t application_id,
    DiscordBridgeAuthCallback callback
);

void discord_bridge_set_status_callback(
    DiscordBridgeStatusCallback callback,
    void *context
);

void discord_bridge_update_presence(
    const char *details,
    const char *state,
    const char *large_image,
    const char *large_image_text,
    const char *small_image,
    const char *small_image_text,
    int show_elapsed_time
);

void discord_bridge_clear_presence(void);
void discord_bridge_login_with_refresh_token(
    uint64_t application_id,
    const char *refresh_token,
    DiscordBridgeAuthCallback callback
);

#ifdef __cplusplus
}
#endif

#endif
