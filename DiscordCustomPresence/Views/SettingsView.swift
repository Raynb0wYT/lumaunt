import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "gear")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Settings")
                .font(.title)
                .fontWeight(.semibold)

            Text("Configure Rich Presence Manager.")
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .navigationTitle("Settings")
    }
}
