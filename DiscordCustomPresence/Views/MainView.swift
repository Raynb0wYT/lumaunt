import SwiftUI

struct MainView: View {
    @Bindable var appState: AppState

    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink {
                    PresenceEditorView(appState: appState)
                } label: {
                    Label(
                        "Presence",
                        systemImage: "person.crop.circle.badge.checkmark"
                    )
                }

                NavigationLink {
                    ImagesView(appState: appState)
                } label: {
                    Label(
                        "Images",
                        systemImage: "photo"
                    )
                }

                NavigationLink {
                    ButtonsView(appState: appState)
                } label: {
                    Label(
                        "Buttons",
                        systemImage: "rectangle.and.hand.point.up.left"
                    )
                }

                NavigationLink {
                    PresetsView(appState: appState)
                } label: {
                    Label(
                        "Presets",
                        systemImage: "square.stack"
                    )
                }

                Divider()

                NavigationLink {
                    SettingsView(appState: appState)
                } label: {
                    Label(
                        "Settings",
                        systemImage: "gear"
                    )
                }

                Section {
                    DiscordAccountView(appState: appState)
                }
            }
            .navigationTitle("RichPresence")
        } detail: {
            PresenceEditorView(appState: appState)
        }
        .frame(
            minWidth: 800,
            minHeight: 550
        )
    }
}
