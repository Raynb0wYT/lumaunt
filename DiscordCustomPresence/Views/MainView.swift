import SwiftUI

struct MainView: View {
    @Bindable var appState: AppState

    @State private var selection: SidebarItem? = .presence

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(
                    min: 210,
                    ideal: 225,
                    max: 250
                )
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(
                placement: .principal
            ) {
                EmptyView()
            }
        }
    }
    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {

            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 20
                ) {

                    // MARK: Presence

                    sidebarButton(
                        item: .presence,
                        title: "Presence",
                        systemImage: "sparkles"
                    )

                    // MARK: Customize

                    sidebarSection("CUSTOMIZE") {
                        sidebarButton(
                            item: .images,
                            title: "Images",
                            systemImage: "photo"
                        )

                        sidebarButton(
                            item: .buttons,
                            title: "Buttons",
                            systemImage: "rectangle.and.hand.point.up.left"
                        )
                    }

                    // MARK: Library

                    sidebarSection("LIBRARY") {
                        sidebarButton(
                            item: .presets,
                            title: "Presets",
                            systemImage: "square.stack.3d.up"
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 16)
            }

            Spacer(minLength: 12)

            // MARK: Bottom Area

            VStack(spacing: 12) {

                Divider()
                    .padding(.horizontal, 12)

                sidebarButton(
                    item: .settings,
                    title: "Settings",
                    systemImage: "gearshape"
                )
                .padding(.horizontal, 12)

                discordAccountCard
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .frame(
            minWidth: 210,
            maxWidth: 250
        )
    }

    // MARK: - Sidebar Section

    private func sidebarSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            Text(title)
                .font(.system(
                    size: 10,
                    weight: .semibold
                ))
                .foregroundStyle(.tertiary)
                .tracking(0.7)
                .padding(.horizontal, 10)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 3) {
                content()
            }
        }
    }

    // MARK: - Sidebar Button

    // MARK: - Sidebar Button

    private func sidebarButton(
        item: SidebarItem,
        title: String,
        systemImage: String
    ) -> some View {
        Button {
            selection = item
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(
                        size: 15,
                        weight: .medium
                    ))
                    .frame(width: 20)

                Text(title)
                    .font(.system(
                        size: 14,
                        weight: selection == item
                            ? .semibold
                            : .medium
                    ))

                Spacer()
            }
            .foregroundStyle(
                selection == item
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                Color(
                                    red: 0.18,
                                    green: 0.72,
                                    blue: 1.0
                                ),
                                Color(
                                    red: 0.48,
                                    green: 0.30,
                                    blue: 1.0
                                )
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    : AnyShapeStyle(
                        Color.primary
                    )
            )
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background {
                if selection == item {
                    RoundedRectangle(
                        cornerRadius: 9,
                        style: .continuous
                    )
                    .fill(
                        Color.accentColor
                            .opacity(0.12)
                    )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .onKeyPress(.space) {
            selection = item
            return .handled
        }
        .accessibilityLabel(title)
        .accessibilityValue(
            selection == item
                ? "Selected"
                : ""
        )
        .keyboardShortcut(
            item.shortcut,
            modifiers: .command
        )
    }

    // MARK: - Discord Account Card

    @ViewBuilder
    private var discordAccountCard: some View {
        switch appState.discord.connectionState {

        case .connected:
            connectedAccountCard

        case .connecting:
            disconnectedAccountCard(
                title: "Connecting…",
                subtitle: "Connecting to Discord",
                systemImage:
                    "arrow.trianglehead.2.clockwise",
                showConnectButton: false
            )

        case .authorizing:
            disconnectedAccountCard(
                title: "Authorizing…",
                subtitle: "Waiting for Discord",
                systemImage: "person.badge.clock",
                showConnectButton: false
            )

        case .discordUnavailable:
            disconnectedAccountCard(
                title: "Discord Offline",
                subtitle: "Open Discord to connect",
                systemImage:
                    "exclamationmark.circle",
                showConnectButton: true
            )

        case .error:
            disconnectedAccountCard(
                title: "Connection Error",
                subtitle: "Unable to connect",
                systemImage:
                    "exclamationmark.triangle",
                showConnectButton: true
            )

        case .disconnected:
            disconnectedAccountCard(
                title: "Discord",
                subtitle: "Not connected",
                systemImage: "person.crop.circle",
                showConnectButton: true
            )
        }
    }

    // MARK: - Connected Account

    private var connectedAccountCard: some View {
        HStack(spacing: 10) {

            ZStack(alignment: .bottomTrailing) {
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
                            .fill(.quaternary)
                            .overlay {
                                Image(
                                    systemName: "person.fill"
                                )
                                .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(
                    width: 34,
                    height: 34
                )
                .clipShape(Circle())
                .accessibilityHidden(true)

                Circle()
                    .fill(.green)
                    .frame(
                        width: 10,
                        height: 10
                    )
                    .overlay {
                        Circle()
                            .stroke(
                                Color(
                                    nsColor:
                                        .windowBackgroundColor
                                ),
                                lineWidth: 2
                            )
                    }
            }

            VStack(
                alignment: .leading,
                spacing: 1
            ) {
                Text(
                    appState.discord.displayName
                        ?? "Discord User"
                )
                .font(.system(
                    size: 13,
                    weight: .semibold
                ))
                .lineLimit(1)

                if let username =
                    appState.discord.username {

                    Text("@\(username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Menu {
                Button {
                    appState.discord.disconnect()
                } label: {
                    Label(
                        "Disconnect Discord",
                        systemImage:
                            "rectangle.portrait.and.arrow.right"
                    )
                }
            } label: {
                Image(
                    systemName: "ellipsis"
                )
                .font(.system(
                    size: 13,
                    weight: .semibold
                ))
                .foregroundStyle(.secondary)
                .frame(
                    width: 26,
                    height: 26
                )
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Discord account options")
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(10)
        .background {
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .fill(.quaternary.opacity(0.25))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .stroke(
                .quaternary,
                lineWidth: 1
            )
        }
    }

    // MARK: - Disconnected Account

    private func disconnectedAccountCard(
        title: String,
        subtitle: String,
        systemImage: String,
        showConnectButton: Bool
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 9
        ) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(
                    alignment: .leading,
                    spacing: 1
                ) {
                    Text(title)
                        .font(.system(
                            size: 13,
                            weight: .semibold
                        ))

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if showConnectButton {
                Button("Connect Discord") {
                    appState.discord.connect()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(10)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background {
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .fill(.quaternary.opacity(0.25))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .stroke(
                .quaternary,
                lineWidth: 1
            )
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .presence {

        case .presence:
            PresenceEditorView(
                appState: appState
            )

        case .images:
            ImagesView(
                appState: appState
            )

        case .buttons:
            ButtonsView(
                appState: appState
            )

        case .presets:
            PresetsView(
                appState: appState
            )

        case .settings:
            SettingsView(
                appState: appState
            )
        }
    }
}

// MARK: - Sidebar Item

private enum SidebarItem:
    Hashable {
    case presence
    case images
    case buttons
    case presets
    case settings

    var shortcut: KeyEquivalent {
        switch self {
        case .presence: return "1"
        case .images: return "2"
        case .buttons: return "3"
        case .presets: return "4"
        case .settings: return "5"
        }
    }
}
