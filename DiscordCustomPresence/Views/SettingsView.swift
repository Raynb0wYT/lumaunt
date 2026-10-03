import SwiftUI
import ServiceManagement
import AppKit

#if DEBUG
import Sentry
#endif

struct SettingsView: View {
    @Bindable var appState: AppState
    @AppStorage("usesSystemAppearance") private var usesSystemAppearance = true
    @AppStorage("isDarkMode") private var isDarkMode = false

    @AppStorage("hideAfterApplyingPresence")
    private var hideAfterApplyingPresence = false

    @AppStorage("restoreLastPresenceOnLaunch")
    private var restoreLastPresenceOnLaunch = false

    @AppStorage("clearPresenceOnQuit")
    private var clearPresenceOnQuit = false

    @AppStorage(CrashReporting.preferenceKey)
    private var shareCrashReports = false

    @State private var launchAtLogin =
        SMAppService.mainApp.status == .enabled

    @State private var loginItemError: String?

    @State private var isShowingClearCacheAlert =
        false

    #if DEBUG
    @State private var sentryTestConfirmation: String?
    #endif


    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 28
            ) {
                header

                VStack(alignment: .leading, spacing: 12) {
                    Text("Appearance").font(.headline)
                    Toggle("Use System Appearance", isOn: $usesSystemAppearance)
                        .accessibilityHint(
                            "Automatically matches the macOS light or dark appearance."
                        )
                    Picker("Color Scheme", selection: $isDarkMode) {
                        Text("Light").tag(false)
                        Text("Dark").tag(true)
                    }
                    .pickerStyle(.menu)
                    .disabled(usesSystemAppearance)
                    .accessibilityHint(
                        "Switches Lumaunt between light and dark appearances."
                    )
                    Text("Keyboard: ⌘1–5 opens a section. ⌘Return applies your presence; ⇧⌘Return disables it. Use Tab and Shift-Tab to move through fields and controls.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ImagePrivacyView(appState: appState)
                generalSection

                presenceSection

                discordSection

                storageSection

                privacySection

                aboutSection
            }
            .padding(32)
            .frame(
                maxWidth: 760,
                alignment: .leading
            )
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
        .navigationTitle("Settings")
        .onAppear {
            refreshLaunchAtLoginStatus()

            appState
                .refreshStorageInformation()
        }
        .alert(
            "Clear Local Image Cache?",
            isPresented:
                $isShowingClearCacheAlert
        ) {
            Button(
                "Clear Cache",
                role: .destructive
            ) {
                appState
                    .clearLocalImageCache()
            }

            Button(
                "Cancel",
                role: .cancel
            ) {}
        } message: {
            Text(
                "This removes locally stored Lumaunt images and the local upload cache. Images already uploaded to Lumaunt's image service are not deleted."
            )
        }
    }


    // MARK: - Header

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            Text(
                "Customize how Lumaunt behaves on your Mac."
            )
            .font(.body)
            .foregroundStyle(.secondary)
        }
    }


    // MARK: - General

    private var generalSection: some View {
        settingsCard(
            title: "General",
            systemImage: "gearshape"
        ) {
            settingToggle(
                title: "Launch Lumaunt at Login",
                description:
                    "Automatically start Lumaunt when you log in to your Mac.",
                isOn: Binding(
                    get: {
                        launchAtLogin
                    },
                    set: { newValue in
                        setLaunchAtLogin(
                            newValue
                        )
                    }
                )
            )

            if let loginItemError {
                Label(
                    loginItemError,
                    systemImage:
                        "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.red)
            }

            settingsDivider

            settingToggle(
                title:
                    "Hide to menu bar after applying",
                description:
                    "Hide Lumaunt's main window after you successfully apply a presence.",
                isOn:
                    $hideAfterApplyingPresence
            )
        }
    }


    // MARK: - Presence

    private var presenceSection: some View {
        settingsCard(
            title: "Presence",
            systemImage: "sparkles"
        ) {
            settingToggle(
                title:
                    "Restore last presence on launch",
                description:
                    "Automatically reapply your most recently used presence when Lumaunt starts and Discord becomes available.",
                isOn:
                    $restoreLastPresenceOnLaunch
            )

            settingsDivider

            settingToggle(
                title:
                    "Clear presence when quitting",
                description:
                    "Ask Discord to remove Lumaunt's active Rich Presence when the app quits.",
                isOn:
                    $clearPresenceOnQuit
            )
        }
    }


    // MARK: - Discord

    private var discordSection: some View {
        settingsCard(
            title: "Discord",
            systemImage: "person.crop.circle"
        ) {
            HStack(spacing: 14) {
                discordAvatar

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text(
                        discordAccountTitle
                    )
                    .fontWeight(.semibold)

                    Text(discordStatusText)
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )

                    if
                        appState.discord
                            .connectionState ==
                            .connected,
                        let username =
                            appState.discord
                                .username
                    {
                        Text("@\(username)")
                            .font(.caption)
                            .foregroundStyle(
                                .tertiary
                            )
                    }
                }

                Spacer()

                discordAction
            }
        }
    }


    @ViewBuilder
    private var discordAction: some View {
        switch appState.discord.connectionState {

        case .connected:
            Button("Disconnect") {
                appState.discord.disconnect()
            }
            .buttonStyle(.bordered)

        case .connecting,
             .authorizing:
            ProgressView()
                .controlSize(.small)

        case .disconnected,
             .discordUnavailable,
             .error:
            Button("Connect Discord") {
                appState.discord.connect()
            }
            .buttonStyle(.borderedProminent)
        }
    }


    private var discordAvatar: some View {
        AsyncImage(
            url: appState.discord.avatarURL
        ) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()

            default:
                Circle()
                    .fill(
                        Color.secondary
                            .opacity(0.12)
                    )
                    .overlay {
                        Image(
                            systemName:
                                "person.fill"
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
            }
        }
        .frame(
            width: 46,
            height: 46
        )
        .clipShape(Circle())
        .accessibilityHidden(true)
    }


    // MARK: - Storage

    private var storageSection: some View {
        settingsCard(
            title: "Images & Storage",
            systemImage: "externaldrive"
        ) {
            HStack {
                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text("Local Image Storage")
                        .fontWeight(.medium)

                    Text(
                        storageDescription
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer()

                Text(
                    formattedStorageSize
                )
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )
            }

            settingsDivider

            HStack {
                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text("Upload Cache")
                        .fontWeight(.medium)

                    Text(
                        "\(appState.cachedUploadCount) cached upload\(appState.cachedUploadCount == 1 ? "" : "s")"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer()

                Button(
                    "Clear Cache…",
                    role: .destructive
                ) {
                    isShowingClearCacheAlert =
                        true
                }
                .disabled(
                    appState.localImageCount == 0 &&
                    appState.cachedUploadCount == 0
                )
            }

            if let storageError =
                appState.storageError {

                settingsDivider

                Label(
                    storageError,
                    systemImage:
                        "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.red)
            }
        }
    }


    // MARK: - Privacy

    private var privacySection: some View {
        settingsCard(
            title: "Privacy",
            systemImage: "hand.raised"
        ) {
            settingToggle(
                title: "Share Crash Reports",
                description:
                    "Automatically send crash and diagnostic information to help improve Lumaunt.",
                isOn: Binding(
                    get: {
                        shareCrashReports
                    },
                    set: { newValue in
                        shareCrashReports = newValue
                        CrashReporting.setEnabled(
                            newValue
                        )
                    }
                )
            )

            settingsDivider

            Text(
                "Crash reports do not intentionally include your Discord credentials, Rich Presence content, moderation text, or uploaded images."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(
                horizontal: false,
                vertical: true
            )

            #if DEBUG
            settingsDivider

            HStack(spacing: 12) {
                Button("Send Test Crash Report") {
                    CrashReporting
                        .sendDebugTestEvent()
                    sentryTestConfirmation =
                        "Test event sent."
                }
                .buttonStyle(.bordered)
                .disabled(
                    !shareCrashReports ||
                    !SentrySDK.isEnabled
                )

                if let sentryTestConfirmation {
                    Label(
                        sentryTestConfirmation,
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            #endif
        }
    }


    // MARK: - About

    private var aboutSection: some View {
        settingsCard(
            title: "About",
            systemImage: "info.circle"
        ) {
            HStack(spacing: 14) {
                Image("LumauntMenuBarIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: 42,
                        height: 42
                    )
                    .accessibilityHidden(true)

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text("Lumaunt")
                        .font(.headline)

                    Text(versionText)
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                }

                Spacer()

                Button("Website") {
                    openWebsite()
                }
                .buttonStyle(.bordered)
            }

            settingsDivider

            Text(
                "Lumaunt lets you create and manage custom Discord Rich Presence configurations from macOS."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }


    // MARK: - Settings Card

    private func settingsCard<
        Content: View
    >(
        title: String,
        systemImage: String,
        @ViewBuilder content:
            () -> Content
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            Label(
                title,
                systemImage: systemImage
            )
            .font(.headline)
            .accessibilityAddTraits(.isHeader)

            content()
        }
        .padding(18)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background {
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .fill(
                Color.secondary
                    .opacity(0.08)
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .stroke(
                Color.secondary
                    .opacity(0.12),
                lineWidth: 1
            )
        }
    }


    // MARK: - Setting Toggle

    private func settingToggle(
        title: String,
        description: String,
        isOn: Binding<Bool>
    ) -> some View {

        HStack(
            alignment: .top,
            spacing: 20
        ) {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(title)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }

            Spacer()

            Toggle(
                "",
                isOn: isOn
            )
            .labelsHidden()
            .accessibilityLabel(title)
            .accessibilityHint(description)
        }
    }


    private var settingsDivider: some View {
        Divider()
    }


    // MARK: - Launch at Login

    private func setLaunchAtLogin(
        _ enabled: Bool
    ) {
        do {
            if enabled {
                try SMAppService
                    .mainApp
                    .register()
            } else {
                try SMAppService
                    .mainApp
                    .unregister()
            }

            refreshLaunchAtLoginStatus()

            loginItemError = nil

        } catch {
            refreshLaunchAtLoginStatus()

            loginItemError =
                "Unable to update Launch at Login."

            print(
                "Failed to update Launch at Login:",
                error.localizedDescription
            )
        }
    }


    private func refreshLaunchAtLoginStatus() {
        launchAtLogin =
            SMAppService
                .mainApp
                .status == .enabled
    }


    // MARK: - Discord Information

    private var discordAccountTitle: String {
        if appState.discord.connectionState ==
            .connected {

            return appState.discord.displayName
                ?? "Discord User"
        }

        return "Discord"
    }


    private var discordStatusText: String {
        switch appState.discord.connectionState {

        case .connected:
            return "Connected"

        case .connecting:
            return "Connecting to Discord…"

        case .authorizing:
            return "Waiting for authorization…"

        case .discordUnavailable:
            return "Discord is offline"

        case .error:
            return "Connection error"

        case .disconnected:
            return "Not connected"
        }
    }


    // MARK: - Storage Information

    private var storageDescription: String {
        "\(appState.localImageCount) locally stored image\(appState.localImageCount == 1 ? "" : "s")"
    }


    private var formattedStorageSize: String {
        ByteCountFormatter.string(
            fromByteCount:
                appState.localImageStorageSize,
            countStyle: .file
        )
    }


    // MARK: - Version

    private var versionText: String {
        let version =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleShortVersionString"
            ) as? String ?? "Development"

        let build =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleVersion"
            ) as? String

        if
            let build,
            !build.isEmpty
        {
            return "Version \(version) (\(build))"
        }

        return "Version \(version)"
    }


    // MARK: - Website

    private func openWebsite() {
        guard let url =
            URL(
                string:
                    "https://lumaunt.app"
            )
        else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
