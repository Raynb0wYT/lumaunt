#include "DiscordBridge.h"
#include <conio.h>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <thread>
constexpr uint64_t applicationId = 1553944326076375230; // Public OAuth client ID, not a secret.
static bool ready = false;
static bool connecting = false;
static void status(DiscordBridgeStatus value, void*) { ready = value == DiscordBridgeStatusReady; if (ready) connecting = false; std::printf("Connection state: %d\n", static_cast<int>(value)); }
static void authorized(int success, const char*, const char*, const char*, int64_t) { if (!success) connecting = false; std::puts(success ? "Authorization accepted; waiting for Ready." : "Authorization failed. Retry with C."); }
static void published(int success, const char*, void*) { std::puts(success ? "Presence applied." : "Presence failed."); }
int main(int argc, char** argv) {
    if (argc == 2 && std::strcmp(argv[1], "--self-check") == 0) {
        auto before = discord_bridge_connection_generation();
        discord_bridge_initialize(applicationId);
        auto created = discord_bridge_connection_generation();
        discord_bridge_run_callbacks();
        discord_bridge_shutdown();
        auto closed = discord_bridge_connection_generation();
        discord_bridge_shutdown();
        discord_bridge_initialize(applicationId);
        auto recreated = discord_bridge_connection_generation();
        discord_bridge_shutdown();
        if (!(created > before && closed > created && recreated > closed)) return 1;
        std::puts("PASS: real SDK client creation, explicit shutdown, repeated shutdown, and recreation.");
        return 0;
    }
    std::puts("Lumaunt Windows Discord lifecycle test. No session credentials are saved.\nC: connect  P: publish fixed test presence  X: clear presence  D: disconnect  Q: quit");
    discord_bridge_set_status_callback(status, nullptr);
    bool running = true;
    while (running) {
        discord_bridge_run_callbacks();
        if (_kbhit()) {
            switch (_getch()) {
                case 'c': case 'C': if (!ready && !connecting) { connecting = true; discord_bridge_initialize(applicationId); discord_bridge_authorize(applicationId, authorized); } break;
                case 'p': case 'P': if (ready) discord_bridge_update_presence("Testing Lumaunt on Windows", "Connection lifecycle verification", "", "", "", "", "", "", "", "", 0, 0, published, nullptr); else std::puts("Wait for Ready before publishing."); break;
                case 'x': case 'X': if (ready) discord_bridge_clear_presence(); break;
                case 'd': case 'D': discord_bridge_clear_presence(); discord_bridge_shutdown(); ready = false; connecting = false; break;
                case 'q': case 'Q': running = false; break;
            }
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
    discord_bridge_clear_presence();
    discord_bridge_shutdown();
}
