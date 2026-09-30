import SwiftUI

struct DiscordAccountView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Discord")
                .font(.caption)
                .foregroundStyle(.secondary)

            switch appState.discord.connectionState {
            case .disconnected:
                disconnectedView

            case .authorizing:
                statusView(
                    text: "Waiting for authorization...",
                    icon: "person.badge.clock"
                )

            case .connecting:
                statusView(
                    text: "Connecting...",
                    icon: "arrow.trianglehead.2.clockwise"
                )

            case .connected:
                connectedView

            case .discordUnavailable:
                statusView(
                    text: "Discord Offline",
                    icon: "exclamationmark.circle"
                )

            case .error(let message):
                errorView(message)
            }
        }
    }

    private var disconnectedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Not Connected", systemImage: "circle")
                .foregroundStyle(.secondary)

            Button("Connect Discord") {
                appState.discord.connect()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var connectedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: appState.discord.avatarURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(.quaternary)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.secondary)
                            }
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())

                    Circle()
                        .fill(.green)
                        .frame(width: 10, height: 10)
                        .overlay {
                            Circle()
                                .stroke(.background, lineWidth: 2)
                        }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(
                        appState.discord.displayName
                            ?? "Discord User"
                    )
                    .fontWeight(.medium)

                    if let username = appState.discord.username {
                        Text("@\(username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button("Disconnect") {
                appState.discord.disconnect()
            }
        }
    }

    private func statusView(
        text: String,
        icon: String
    ) -> some View {
        Label(text, systemImage: icon)
            .foregroundStyle(.secondary)
    }

    private func errorView(
        _ message: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                "Connection Error",
                systemImage: "exclamationmark.triangle"
            )
            .foregroundStyle(.red)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Try Again") {
                appState.discord.connect()
            }
        }
    }
}
