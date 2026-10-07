# Lumaunt for Windows

Windows application source for Lumaunt 1.0.0. The WPF application and its C++ Discord Social SDK bridge live entirely in this directory. The macOS app is separate.

## Features

- Discord OAuth, protected local sessions, refresh rotation, restoration and explicit connection teardown.
- Rich Presence details/state, live preview, elapsed/custom-start/countdown timers and optional timer-end disabling.
- Large/small images, hover text, file selection, drag-and-drop, clipboard paste and optional hosted uploads with retention/deletion controls.
- Two reorderable buttons; presets with save/load/apply/rename/duplicate/delete and search.
- Dark/light/system appearance, keyboard navigation, account avatar, tray controls and optional launch-at-login.
- Optional Sentry crash reporting, disabled by default; no usage analytics or performance tracing.

## Build on Windows

Prerequisites: .NET 10 SDK, Visual Studio 2022 C++ desktop tools with matching x64/ARM64 compiler and redistribution files, CMake, Discord Social SDK 1.10.19337 Windows package, and Inno Setup 6.7+ for EXE installers. Download the Discord SDK separately; SDK binaries and generated build outputs are not included in this repository.

```powershell
./scripts/build-native.ps1 -SdkRoot "C:/path/to/discord_social_sdk" -Architecture x64
./scripts/build-ui.ps1 -Runtime win-x64
./scripts/build-installer.ps1 -Runtime win-x64
./artifacts/win-x64/Lumaunt.exe
```

For ARM64, use `-Architecture ARM64` and `-Runtime win-arm64`. The UI build copies matching native SDK and Visual C++ runtimes, and runs the isolated feature checks. Installer scripts derive the installer version from the built executable. EXE outputs are under `artifacts/installers/` and remain unsigned unless a trusted signing workflow is configured.

For MSIX packaging, install the Windows SDK and build both architectures first:

```powershell
./scripts/build-store.ps1 -IdentityPath ./store/identity.json
```

The included identity contains Lumaunt's public Partner Center identifiers. Use your own product identity for a different Store app. Packaging does not grant Microsoft approval or sign the standalone EXE installers. Confirm SDK redistribution terms before distributing bundled binaries. Preserve all included third-party license notices.

## Checks

```powershell
dotnet run --project ./Lumaunt.Core.Checks --configuration Release
./artifacts/win-x64/Lumaunt.exe --check-windows-features
```

Core checks exercise validation, timers, moderation parity and session-expiry decisions. Windows checks use isolated temporary storage, SDK lifecycle tests, DPAPI, WPF resources/layouts and fake service transports; they do not log into Discord, publish presence or upload real images. Unpackaged reports are written beside the executable; packaged reports use the current user's temporary directory. Live Discord, real service behavior and target-platform testing require separate manual verification.

## User data and privacy

Settings, presets and cached images are stored under `%LOCALAPPDATA%/Lumaunt`. Discord credentials and image ownership tokens are protected with current-user DPAPI. Uninstall preserves user data. Hosted images and contextual moderation use the existing Lumaunt backend. The Sentry ingestion DSN and OAuth client ID in source are public client identifiers, not private API tokens.

## Platform and release status

x64 packages target Windows 10 build 19041 or later; ARM64 packages target Windows 11 build 22000 or later. ARM64 and emulated x64 checks passed in the Windows 11 ARM VM; native x64 feature/startup checks passed on Windows 11. Windows 10 compatibility and sleep/wake recovery have not been verified separately. User testing confirmed other-account presence visibility, disconnect/reconnect, session restoration, timers and real image uploads/deletion.

Store certification remains pending: the native WACK run reports a DPI analyzer warning despite a passing actual PerMonitorV2 runtime check. Standalone installers are unsigned. Source availability is not a claim of Microsoft Store approval.
