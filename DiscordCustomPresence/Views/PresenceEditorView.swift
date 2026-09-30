import SwiftUI

struct PresenceEditorView: View {
    @Bindable var appState: AppState

    var body: some View {
        Form {

            Section("Presence") {
                TextField(
                    "Details",
                    text: $appState.presence.details
                )

                TextField(
                    "State",
                    text: $appState.presence.state
                )

                Toggle(
                    "Show elapsed time",
                    isOn: $appState.presence.showElapsedTime
                )
            }

            Section("Preview") {
                PresencePreviewView(
                    presence: appState.presence
                )
            }

            Section {
                HStack {
                    Button {
                        Task {
                            await appState.applyPresence()
                        }
                    } label: {
                        if appState.isApplyingPresence {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)

                                Text("Applying…")
                            }
                        } else {
                            Text("Apply Presence")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        appState.discord.connectionState != .connected ||
                        appState.isApplyingPresence
                    )
                    .help(
                        appState.discord.connectionState == .connected
                            ? "Apply this presence to Discord"
                            : "Connect your Discord account first"
                    )
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        appState.discord.connectionState != .connected
                    )
                    .help(
                        appState.discord.connectionState == .connected
                            ? "Apply this presence to Discord"
                            : "Connect your Discord account first"
                    )

                    Button("Disable Presence") {
                        appState.clearPresence()
                    }
                    .buttonStyle(.bordered)
                    .disabled(
                        appState.discord.connectionState != .connected
                    )
                    .help(
                        appState.discord.connectionState == .connected
                            ? "Remove your current Rich Presence from Discord"
                            : "Connect your Discord account first"
                    )
                }
                if let error = appState.presenceError {
                    Label(
                        error,
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Presence")
        .padding()
    }
}
