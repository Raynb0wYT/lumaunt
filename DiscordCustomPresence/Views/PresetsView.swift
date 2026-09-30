import SwiftUI

struct PresetsView: View {
    @Bindable var appState: AppState

    @State private var presetName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Presets")
                .font(.largeTitle)
                .fontWeight(.bold)

            HStack {
                TextField("Preset Name", text: $presetName)

                Button("Save Current Presence") {
                    let cleanedName = presetName
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    guard !cleanedName.isEmpty else {
                        return
                    }

                    appState.presetStore.savePreset(
                        name: cleanedName,
                        configuration: appState.presence
                    )

                    presetName = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    presetName
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
                )
            }

            if appState.presetStore.presets.isEmpty {
                ContentUnavailableView(
                    "No Presets",
                    systemImage: "square.stack",
                    description: Text(
                        "Configure a presence and save it as a preset."
                    )
                )
            } else {
                List {
                    ForEach(appState.presetStore.presets) { preset in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(preset.name)
                                    .fontWeight(.medium)

                                Text(preset.configuration.details)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Load") {
                                appState.presence = preset.configuration
                            }

                            Button(role: .destructive) {
                                appState.presetStore.deletePreset(preset)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .navigationTitle("Presets")
    }
}
