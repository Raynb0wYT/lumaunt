# Lumaunt ✦

**Your Discord presence. Your way.**

Lumaunt is a desktop application for **macOS and Windows** that lets you create, customize, and manage your Discord Rich Presence.

Customize your presence with text, images, buttons, timers, and presets, with a live preview and controls that keep privacy in your hands.

## Features

- **Custom Rich Presence** — edit details and state, apply changes, or disable your presence.
- **Live preview** — see your configuration as you customize it.
- **Images and hover text** — add large and small artwork using image URLs, local files, or clipboard images.
- **Custom buttons** — add up to two links and choose their order.
- **Timers** — elapsed time, custom start times, and countdowns with optional automatic disabling.
- **Presets** — save, search, load, apply, rename, duplicate, and delete configurations.
- **Discord connection** — connect through Discord authentication and restore your locally protected session.
- **Privacy controls** — opt into hosted image uploads, choose retention periods, delete managed uploads, and control optional crash reporting.
- **Desktop integration** — account avatars, menu bar or system tray controls, optional launch at login, and presence restoration.
- **Appearance and navigation** — Light, Dark, and System appearance, responsive layouts, keyboard shortcuts, and accessibility support.

## Download

Choose the file for your computer. All downloads are available on [GitHub Releases](https://github.com/Raynb0wYT/lumaunt/releases).

| Platform | Download |
| --- | --- |
| macOS — Apple silicon and Intel | [Lumaunt 1.0.1 (.dmg)](https://github.com/Raynb0wYT/lumaunt/releases/download/Minor-Release/Lumaunt-1.0.1.dmg) |
| Windows — Intel and AMD x64 | [Lumaunt 1.0.0 installer](https://github.com/Raynb0wYT/lumaunt/releases/download/Windows-1.0.0/Lumaunt-1.0.0-win-x64-setup.exe) |
| Windows — ARM64 | [Lumaunt 1.0.0 installer](https://github.com/Raynb0wYT/lumaunt/releases/download/Windows-1.0.0/Lumaunt-1.0.0-win-arm64-setup.exe) |

### Install on macOS

Open the disk image, drag **Lumaunt** into **Applications**, then open Lumaunt and connect Discord.

Lumaunt is not currently notarized with an Apple Developer ID. macOS may display a security warning on first launch.

### Install on Windows

Run the matching x64 or ARM64 installer, then open Lumaunt and connect Discord.

The Windows installers are currently **unsigned**, so Windows may display a SmartScreen warning. Microsoft Store availability is pending.

## Requirements

- A supported macOS or Windows computer.
- A Discord account.
- Internet access for authentication and online features.

macOS builds support Apple silicon and Intel Macs. Windows x64 builds target Windows 10 version 2004 (build 19041) or later; ARM64 builds target Windows 11. Windows 11 has been tested on ARM64 and native x64 hardware. Windows 10 compatibility and sleep/wake recovery still require separate verification. There is no 32-bit Windows or Linux release.

## Privacy

Lumaunt keeps settings, presets, and Discord authentication credentials on your computer. Credentials are protected using **macOS Keychain** on Mac and **Windows DPAPI** on Windows.

Content moderation and optional hosted images use Lumaunt's backend and third-party service providers. Optional crash reporting is disabled by default.

Read the [Privacy Policy](https://lumaunt.app/privacy/) for details.

## Building from source

The repository contains separate platform implementations:

- **macOS:** Swift and SwiftUI in the Xcode project.
- **Windows:** WPF/.NET and a C++ Discord Social SDK bridge in [`windows/`](windows/).

Clone the repository:

```bash
git clone https://github.com/Raynb0wYT/lumaunt.git
cd lumaunt
```

For macOS, open the project in Xcode:

```bash
open Lumaunt.xcodeproj
```

For Windows, follow the prerequisites, build commands, and checks in the [Windows build guide](windows/README.md).

Download the Discord Social SDK separately. Some functionality may require additional configuration that is intentionally not included in the repository. Generated builds and installers are distributed through Releases rather than committed as source.

## Rich Presence Not Showing?

Is your Discord rich presence not showing? If it is not, make sure that your Discord activity sharing is enabled. To do this, go to settings, scroll down to "Activity Privacy", and then enable the "Share my Activity" button. If it is still not working, try disconnecting your Discord account and reconnecting it, along with restarting the program. Still having issues? Contact me on Discord: **rayn.f**

## Support

Visit [Lumaunt Support](https://lumaunt.app/support/) or report bugs through [GitHub Issues](https://github.com/Raynb0wYT/lumaunt/issues).

For privacy-related questions: **privacy@lumaunt.app**.

Website: [lumaunt.app](https://lumaunt.app)

## Roadmap

Future development may include automatic updates, additional quality-of-life improvements, more customization options, and Linux support.

## Disclaimer

Lumaunt is an independent project and is **not affiliated with, endorsed by, or sponsored by Discord Inc.**

Discord and related trademarks are the property of their respective owners.
