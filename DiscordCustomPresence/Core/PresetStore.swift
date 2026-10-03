import Foundation
import Observation

@Observable
final class PresetStore {
    var presets: [PresencePreset] = []

    private let fileURL: URL

    init() {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let appFolder = applicationSupport
            .appendingPathComponent("RichPresence")

        try? FileManager.default.createDirectory(
            at: appFolder,
            withIntermediateDirectories: true
        )

        fileURL = appFolder.appendingPathComponent("presets.json")

        load()
    }

    func savePreset(name: String, configuration: PresenceConfiguration) {
        var presetConfiguration = configuration
        presetConfiguration.startTimestamp = nil
        presetConfiguration.endTimestamp = nil

        let preset = PresencePreset(
            name: name,
            configuration: presetConfiguration
        )

        presets.append(preset)
        save()
    }

    func deletePreset(_ preset: PresencePreset) {
        presets.removeAll { $0.id == preset.id }
        save()
    }

    func renamePreset(
        _ preset: PresencePreset,
        to newName: String
    ) {
        let cleanedName = newName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanedName.isEmpty else {
            return
        }

        guard let index = presets.firstIndex(
            where: { $0.id == preset.id }
        ) else {
            return
        }

        presets[index].name = cleanedName
        save()
    }


    func duplicatePreset(
        _ preset: PresencePreset
    ) {
        let duplicate = PresencePreset(
            name: "\(preset.name) Copy",
            configuration: preset.configuration
        )

        guard let index = presets.firstIndex(
            where: { $0.id == preset.id }
        ) else {
            presets.append(duplicate)
            save()
            return
        }

        presets.insert(
            duplicate,
            at: index + 1
        )

        save()
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let data = try encoder.encode(presets)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save presets:", error)
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            presets = try JSONDecoder().decode(
                [PresencePreset].self,
                from: data
            )
        } catch {
            print("Failed to load presets:", error)
        }
    }
}
