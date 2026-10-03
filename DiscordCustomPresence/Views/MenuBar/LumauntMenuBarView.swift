import SwiftUI
import AppKit


struct LumauntMenuBarView: View {

    @Bindable var appState: AppState

    @Environment(\.openWindow)
    private var openWindow

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            // MARK: - Header

            HStack(spacing: 8) {
                Image("LumauntMenuBarIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)

                Text("Lumaunt")
                    .font(.headline)

                Spacer()
            }


            Divider()


            // MARK: - Discord Account

            discordAccount


            // MARK: - Presence

            presenceSection


            Divider()


            // MARK: - Actions

            VStack(
                alignment: .leading,
                spacing: 2
            ) {

                Button {
                    openLumaunt()
                } label: {
                    Label(
                        "Open Lumaunt",
                        systemImage: "macwindow"
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)


                Button {
                    appState.clearPresence()
                } label: {
                    Label(
                        "Disable Presence",
                        systemImage: "stop.circle"
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                .disabled(
                    !appState.discord.hasActivePresence
                )
            }


            Divider()


            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label(
                    "Quit Lumaunt",
                    systemImage: "power"
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
        }
        .padding(12)
        .frame(width: 255)
    }


    // MARK: - Discord Account

    @ViewBuilder
    private var discordAccount: some View {

        switch appState.discord.connectionState {

        case .connected:

            HStack(spacing: 9) {

                AsyncImage(
                    url: appState.discord.avatarURL
                ) { phase in

                    switch phase {

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()

                    default:
                        avatarPlaceholder
                    }
                }
                .frame(width: 30, height: 30)
                .clipShape(Circle())
                .accessibilityHidden(true)


                VStack(
                    alignment: .leading,
                    spacing: 0
                ) {
                    Text(
                        appState.discord.displayName
                        ?? "Discord User"
                    )
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(1)

                    if let username =
                        appState.discord.username {

                        Text("@\(username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }


                Spacer()


                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 7, height: 7)

                    Text("Connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }


        case .connecting:
            statusRow(
                title: "Connecting to Discord…",
                systemImage:
                    "arrow.trianglehead.2.clockwise"
            )


        case .authorizing:
            statusRow(
                title: "Authorizing…",
                systemImage: "person.badge.clock"
            )


        case .discordUnavailable:
            statusRow(
                title: "Discord Offline",
                systemImage:
                    "exclamationmark.circle"
            )


        case .error:
            statusRow(
                title: "Discord Error",
                systemImage:
                    "exclamationmark.triangle"
            )


        case .disconnected:
            statusRow(
                title: "Discord Disconnected",
                systemImage: "circle"
            )
        }
    }


    // MARK: - Presence

    private var presenceSection: some View {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {

            Text("Presence")
                .font(.caption)
                .foregroundStyle(.secondary)


            HStack(spacing: 6) {
                Circle()
                    .fill(
                        appState.discord.hasActivePresence
                        ? .green
                        : .secondary
                    )
                    .frame(width: 7, height: 7)

                Text(
                    appState.discord.hasActivePresence
                    ? "Active"
                    : "No active presence"
                )
                .font(.callout)
                .fontWeight(
                    appState.discord.hasActivePresence
                    ? .medium
                    : .regular
                )

                Spacer()
            }


            if appState.discord.hasActivePresence {

                if let details =
                    appState.discord.activePresenceDetails {

                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.leading, 13)
                }


                if let state =
                    appState.discord.activePresenceState {

                    Text(state)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.leading, 13)
                }
            }
        }
    }


    // MARK: - Helpers

    private var avatarPlaceholder: some View {
        Circle()
            .fill(.quaternary)
            .overlay {
                Image(
                    systemName: "person.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
    }


    private func statusRow(
        title: String,
        systemImage: String
    ) -> some View {

        Label(
            title,
            systemImage: systemImage
        )
        .font(.callout)
    }


    private func openLumaunt() {
        openWindow(id: "main")

        NSApplication.shared.activate(
            ignoringOtherApps: true
        )
    }
}
