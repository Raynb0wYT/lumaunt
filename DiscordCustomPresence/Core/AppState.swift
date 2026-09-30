import Foundation
import Observation

@Observable
final class AppState {
    var presence = PresenceConfiguration()
    var presetStore = PresetStore()
    var discord = DiscordManager()

    var isApplyingPresence = false
    var presenceError: String?

    private let imageUploadService = ImageUploadService()

    init() {
        discord.restoreConnection()
    }

    @MainActor
    func applyPresence() async {
        guard discord.connectionState == .connected else {
            print("Cannot apply presence: Discord is not connected.")
            return
        }

        guard !isApplyingPresence else {
            return
        }

        isApplyingPresence = true
        presenceError = nil

        defer {
            isApplyingPresence = false
        }

        do {
            let resolvedLargeImage = try await resolveImage(
                presence.largeImage
            )

            let resolvedSmallImage = try await resolveImage(
                presence.smallImage
            )

            // Every Apply starts/restarts the presence timer.
            presence.startTimestamp = Date()

            discord.updatePresence(
                details: presence.details,
                state: presence.state,
                largeImage: resolvedLargeImage,
                largeImageText: presence.largeImageText,
                smallImage: resolvedSmallImage,
                smallImageText: presence.smallImageText,
                showElapsedTime: presence.showElapsedTime
            )

            print("Presence applied successfully.")

        } catch {
            presenceError = error.localizedDescription

            print(
                "Failed to apply presence:",
                error.localizedDescription
            )
        }
    }

    func clearPresence() {
        discord.clearPresence()
        presence.startTimestamp = nil
        presenceError = nil
    }

    private func resolveImage(
        _ value: String
    ) async throws -> String {
        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            return ""
        }

        guard let url = URL(string: trimmed) else {
            return trimmed
        }

        // Normal web image — Discord can use it directly.
        if url.scheme == "https" || url.scheme == "http" {
            return trimmed
        }

        // Local image — upload it to Lumaunt's image service.
        if url.isFileURL {
            print("Uploading local image:", url.lastPathComponent)

            let uploadedImage = try await imageUploadService.upload(
                fileURL: url
            )

            print(
                "Image uploaded:",
                uploadedImage.url.absoluteString
            )

            return uploadedImage.url.absoluteString
        }

        return trimmed
    }
}
