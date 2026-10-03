import SwiftUI

struct PresetsView: View {
    @Bindable var appState: AppState

    @State private var isShowingSaveSheet = false
    @State private var presetName = ""
    @State private var searchText = ""

    @State private var presetToRename: PresencePreset?
    @State private var renameText = ""

    @State private var presetToDelete: PresencePreset?

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 28
            ) {
                header

                if appState.presetStore.presets.isEmpty {
                    emptyState
                } else if filteredPresets.isEmpty {
                    noSearchResults
                } else {
                    presetLibrary
                }
            }
            .padding(32)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
        .navigationTitle("Presets")
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: "Search Presets"
        )
        .sheet(isPresented: $isShowingSaveSheet) {
            savePresetSheet
        }
        .sheet(
            item: $presetToRename
        ) { preset in
            renamePresetSheet(preset)
        }
        .alert(
            "Delete Preset?",
            isPresented: deleteAlertBinding,
            presenting: presetToDelete
        ) { preset in
            Button(
                "Delete",
                role: .destructive
            ) {
                appState.presetStore
                    .deletePreset(preset)

                presetToDelete = nil
            }

            Button(
                "Cancel",
                role: .cancel
            ) {
                presetToDelete = nil
            }
        } message: { preset in
            Text(
                "\"\(preset.name)\" will be permanently deleted."
            )
        }
    }


    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                Text("Presets")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)

                Text(
                    "Save your favorite Rich Presence setups " +
                    "and switch between them instantly."
                )
                .font(.body)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                presetName = ""
                isShowingSaveSheet = true
            } label: {
                Label(
                    "New Preset",
                    systemImage: "plus"
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }


    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(
                systemName: "square.stack.3d.up"
            )
            .font(
                .system(
                    size: 44,
                    weight: .light
                )
            )
            .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("No presets yet")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(
                    "Save your current presence to " +
                    "quickly switch back to it later."
                )
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            Button {
                presetName = ""
                isShowingSaveSheet = true
            } label: {
                Label(
                    "New Preset",
                    systemImage: "plus"
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 4)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 360
        )
    }


    // MARK: - Preset Library

    private var presetLibrary: some View {
        LazyVStack(spacing: 12) {
            ForEach(
                filteredPresets
            ) { preset in
                presetCard(preset)
            }
        }
    }


    private var filteredPresets: [PresencePreset] {
        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !query.isEmpty else {
            return appState.presetStore.presets
        }

        return appState.presetStore.presets.filter { preset in
            preset.name.localizedStandardContains(query) ||
            preset.configuration.details.localizedStandardContains(query) ||
            preset.configuration.state.localizedStandardContains(query)
        }
    }


    private var noSearchResults: some View {
        ContentUnavailableView(
            "No Matching Presets",
            systemImage: "magnifyingglass",
            description: Text(
                "Try searching for a different preset name or presence text."
            )
        )
        .frame(
            maxWidth: .infinity,
            minHeight: 360
        )
    }


    // MARK: - Preset Card

    private func presetCard(
        _ preset: PresencePreset
    ) -> some View {
        HStack(spacing: 16) {
            presetArtwork(preset)

            presetInformation(preset)

            Spacer(minLength: 16)

            applyButton(for: preset)

            Button("Load") {
                appState.presence =
                    preset.configuration
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Load preset \(preset.name)")
            .disabled(appState.isApplyingPresence)

            presetMenu(for: preset)
        }
        .padding(16)
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


    // MARK: - Preset Information

    private func presetInformation(
        _ preset: PresencePreset
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 5
        ) {
            Text(preset.name)
                .font(.headline)
                .lineLimit(1)

            if !preset.configuration.details.isEmpty {
                Text(
                    preset.configuration.details
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            if !preset.configuration.state.isEmpty {
                Text(
                    preset.configuration.state
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            }

            presetMetadata(preset)
                .padding(.top, 2)
        }
    }


    // MARK: - Apply Button

    private func applyButton(
        for preset: PresencePreset
    ) -> some View {
        Button {
            appState.presence =
                preset.configuration

            Task {
                await appState.applyPresence()
            }
        } label: {
            Group {
                if appState.isApplyingPresence {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Apply")
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel(
            appState.isApplyingPresence
                ? "Applying preset \(preset.name)"
                : "Apply preset \(preset.name)"
        )
        .disabled(
            appState.discord.connectionState != .connected ||
            appState.isApplyingPresence
        )
    }


    // MARK: - Preset Menu

    private func presetMenu(
        for preset: PresencePreset
    ) -> some View {
        Menu {
            Button {
                appState.presence =
                    preset.configuration
            } label: {
                Label(
                    "Load Preset",
                    systemImage:
                        "square.and.arrow.down"
                )
            }

            Divider()

            Button {
                renameText = preset.name
                presetToRename = preset
            } label: {
                Label(
                    "Rename",
                    systemImage: "pencil"
                )
            }

            Button {
                appState.presetStore
                    .duplicatePreset(preset)
            } label: {
                Label(
                    "Duplicate",
                    systemImage:
                        "plus.square.on.square"
                )
            }

            Divider()

            Button(
                role: .destructive
            ) {
                presetToDelete = preset
            } label: {
                Label(
                    "Delete",
                    systemImage: "trash"
                )
            }
        } label: {
            Image(
                systemName: "ellipsis.circle"
            )
            .font(.title3)
        }
        .accessibilityLabel("Options for \(preset.name)")
        .menuStyle(.borderlessButton)
        .fixedSize()
    }


    // MARK: - Artwork

    @ViewBuilder
    private func presetArtwork(
        _ preset: PresencePreset
    ) -> some View {
        let image =
            preset.configuration.largeImage

        if
            !image.isEmpty,
            let url = URL(string: image)
        {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()

                default:
                    artworkPlaceholder
                }
            }
            .frame(
                width: 64,
                height: 64
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
            )
            .accessibilityLabel("Artwork for \(preset.name)")
        } else {
            artworkPlaceholder
                .frame(
                    width: 64,
                    height: 64
                )
                .accessibilityHidden(true)
        }
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(
            cornerRadius: 10,
            style: .continuous
        )
        .fill(
            Color.secondary
                .opacity(0.12)
        )
        .overlay {
            Image(
                systemName: "sparkles"
            )
            .font(.title2)
            .foregroundStyle(.secondary)
        }
    }


    // MARK: - Metadata

    private func presetMetadata(
        _ preset: PresencePreset
    ) -> some View {
        HStack(spacing: 10) {
            buttonMetadata(preset)

            timerMetadata(preset)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func buttonMetadata(
        _ preset: PresencePreset
    ) -> some View {
        let count =
            preset.configuration.buttons.count

        if count > 0 {
            Label(
                count == 1
                    ? "1 button"
                    : "\(count) buttons",
                systemImage: "link"
            )
        }
    }

    @ViewBuilder
    private func timerMetadata(
        _ preset: PresencePreset
    ) -> some View {
        switch preset.configuration.timerMode {
        case .elapsed:
            Label(
                "Elapsed timer",
                systemImage: "stopwatch"
            )

        case .countdown:
            Label(
                "Countdown",
                systemImage: "timer"
            )
        }
    }


    // MARK: - Save Sheet

    private var savePresetSheet: some View {
        VStack(
            alignment: .leading,
            spacing: 20
        ) {
            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text("Save Preset")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(
                    "Save your current presence, images, " +
                    "buttons, and timer settings."
                )
                .foregroundStyle(.secondary)
            }

            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                Text("Preset Name")
                    .fontWeight(.medium)

                TextField(
                    "Gaming",
                    text: $presetName
                )
                .textFieldStyle(.roundedBorder)
            }

            Spacer()

            HStack {
                Spacer()

                Button("Cancel") {
                    isShowingSaveSheet = false
                }

                Button("Save Preset") {
                    savePreset()
                }
                .buttonStyle(.borderedProminent)
                .disabled(cleanedPresetName.isEmpty)
                .keyboardShortcut(
                    .defaultAction
                )
            }
        }
        .padding(24)
        .frame(
            width: 440,
            height: 220
        )
    }


    // MARK: - Rename Sheet

    private func renamePresetSheet(
        _ preset: PresencePreset
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 20
        ) {
            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text("Rename Preset")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(
                    "Choose a new name for this preset."
                )
                .foregroundStyle(.secondary)
            }

            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                Text("Preset Name")
                    .fontWeight(.medium)

                TextField(
                    "Preset Name",
                    text: $renameText
                )
                .textFieldStyle(.roundedBorder)
            }

            Spacer()

            HStack {
                Spacer()

                Button("Cancel") {
                    presetToRename = nil
                    renameText = ""
                }

                Button("Rename") {
                    appState.presetStore.renamePreset(
                        preset,
                        to: renameText
                    )

                    presetToRename = nil
                    renameText = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(cleanedRenameText.isEmpty)
                .keyboardShortcut(
                    .defaultAction
                )
            }
        }
        .padding(24)
        .frame(
            width: 440,
            height: 210
        )
    }


    // MARK: - Delete Alert

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: {
                presetToDelete != nil
            },
            set: { isPresented in
                if !isPresented {
                    presetToDelete = nil
                }
            }
        )
    }


    // MARK: - Cleaned Text

    private var cleanedPresetName: String {
        presetName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var cleanedRenameText: String {
        renameText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }


    // MARK: - Save

    private func savePreset() {
        guard !cleanedPresetName.isEmpty else {
            return
        }

        appState.presetStore.savePreset(
            name: cleanedPresetName,
            configuration: appState.presence
        )

        presetName = ""
        isShowingSaveSheet = false
    }
}
