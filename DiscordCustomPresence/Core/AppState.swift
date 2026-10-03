import Foundation
import Observation
import AppKit

@Observable
final class AppState {

    var presence = PresenceConfiguration() {
        didSet {
            guard !isLoadingPersistedPresence else {
                return
            }

            saveEditorDraft()
        }
    }
    var presetStore = PresetStore()
    var discord = DiscordManager()

    var isApplyingPresence = false
    var presenceError: String?

    var activeAppliedPresence: PresenceConfiguration?

    var isCurrentPresenceApplied: Bool {
        guard let activeAppliedPresence else {
            return false
        }

        return presence == activeAppliedPresence
    }

    var localImageStorageSize: Int64 = 0
    var localImageCount: Int = 0
    var cachedUploadCount: Int = 0

    var storageError: String?

    private let imageUploadService =
        ImageUploadService()

    private let localImageStore =
        LocalImageStore.shared

    private let imageUploadCache =
        ImageUploadCache.shared

    private var terminationObserver: NSObjectProtocol?
    private var isLoadingPersistedPresence = false
    private var autoDisableTask: Task<Void, Never>?
    private var activePresenceGeneration: UUID?

    private static let lastPresenceKey =
        "lastAppliedPresence"

    private static let editorDraftKey =
        "presenceEditorDraft"

    private static let restorePresenceKey =
        "restoreLastPresenceOnLaunch"

    private static let clearOnQuitKey =
        "clearPresenceOnQuit"


    // MARK: - Errors

    private enum PresenceApplyError: LocalizedError {

        case notConnected
        case connecting
        case authorizing
        case discordUnavailable
        case discordError(String)

        case detailsTooLong
        case stateTooLong
        case largeImageTextTooLong
        case smallImageTextTooLong

        case invalidCountdown

        case contentBlocked(
            fieldName: String,
            category: String,
            reason: String
        )

        case contentReviewBlocked(
            fieldName: String,
            categories: [String]
        )

        case tooManyButtons
        case missingButtonLabel(Int)
        case buttonLabelTooLong(Int)
        case missingButtonURL(Int)
        case invalidButtonURL(Int)

        case invalidImageReference(String)
        case unsupportedImageReference(String)
        case localImageMissing(String)
        case imageUploadFailed(
            imageName: String,
            reason: String
        )

        var errorDescription: String? {
            switch self {

            case .notConnected:
                return
                    "Discord is not connected. Connect your Discord account before applying a presence."

            case .connecting:
                return
                    "Lumaunt is still connecting to Discord. Wait a moment and try again."

            case .authorizing:
                return
                    "Discord authorization is still in progress. Finish connecting your account first."

            case .discordUnavailable:
                return
                    "Discord is currently unavailable. Make sure the Discord desktop app is open, then try again."

            case .discordError(let message):
                let trimmed =
                    message.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                if trimmed.isEmpty {
                    return
                        "Lumaunt could not connect to Discord. Try reconnecting your account."
                }

                return trimmed

            case .detailsTooLong:
                return
                    "Details must be 128 characters or fewer."

            case .stateTooLong:
                return
                    "State must be 128 characters or fewer."

            case .largeImageTextTooLong:
                return
                    "Large image hover text must be 128 characters or fewer."

            case .smallImageTextTooLong:
                return
                    "Small image hover text must be 128 characters or fewer."

            case .invalidCountdown:
                return
                    "Countdown duration must be at least 1 minute."

            case .contentBlocked(
                let fieldName,
                let category,
                let reason
            ):
                return
                    "\(fieldName) was blocked as \(category): \(reason)"

            case .contentReviewBlocked(
                let fieldName,
                let categories
            ):
                let categoryList =
                    categories.joined(
                        separator: ", "
                    )

                return
                    "\(fieldName) could not be applied because it was identified as \(categoryList)."

            case .tooManyButtons:
                return
                    "Discord supports a maximum of 2 presence buttons."

            case .missingButtonLabel(let number):
                return
                    "Button \(number) needs a label."

            case .buttonLabelTooLong(let number):
                return
                    "Button \(number) label must be 32 characters or fewer."

            case .missingButtonURL(let number):
                return
                    "Button \(number) needs a URL."

            case .invalidButtonURL(let number):
                return
                    "Button \(number) needs a valid HTTP or HTTPS URL."

            case .invalidImageReference(let imageName):
                return
                    "\(imageName) has an invalid image reference. Choose a local image or enter a valid HTTP or HTTPS image URL."

            case .unsupportedImageReference(let imageName):
                return
                    "\(imageName) uses an unsupported URL type. Use a local image or an HTTP or HTTPS image URL."

            case .localImageMissing(let imageName):
                return
                    "\(imageName) could not be found on this Mac. Choose the image again and retry."

            case .imageUploadFailed(
                let imageName,
                let reason
            ):
                let trimmed =
                    reason.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                if trimmed.isEmpty {
                    return
                        "\(imageName) could not be uploaded. Try again."
                }

                return
                    "\(imageName) could not be uploaded: \(trimmed)"
            }
        }
    }


    // MARK: - Init

    init() {
        loadEditorDraft()

        configureTerminationObserver()

        discord.restoreConnection()

        if UserDefaults.standard.bool(
            forKey: Self.restorePresenceKey
        ) {
            beginAutomaticPresenceRestore()
        }

        refreshStorageInformation()
    }


    deinit {
        autoDisableTask?.cancel()

        if let terminationObserver {
            NotificationCenter.default.removeObserver(
                terminationObserver
            )
        }
    }


    // MARK: - Apply Presence

    @MainActor
    func applyPresence(
        hideWindowAfterApplying: Bool = true,
        restoredExpiration: Date? = nil
    ) async {

        if let restoredExpiration,
           restoredExpiration <= Date() {
            return
        }

        guard !HostedImageStore.shared.isDeleting else {
            presenceError = "Wait for hosted-image deletion to finish before applying a presence."
            return
        }
        guard !isApplyingPresence else {
            return
        }

        // A new attempt replaces any previous error.
        presenceError = nil


        // MARK: Validate Connection

        do {
            try validateDiscordConnection()
        } catch {
            showPresenceError(error)
            return
        }


        // MARK: Validate Presence

        do {
            try validatePresence()
        } catch {
            showPresenceError(error)
            return
        }


        isApplyingPresence = true

        defer {
            isApplyingPresence = false
        }


        do {

            // MARK: Content Moderation

            try await moderatePresenceContent()

            // Discord could have disconnected while
            // Layer 2 moderation was running.
            try validateDiscordConnection()


            // MARK: Resolve Images

            let resolvedLargeImage =
                try await resolveImage(
                    presence.largeImage,
                    imageName: "Large Image"
                )

            let resolvedSmallImage =
                try await resolveImage(
                    presence.smallImage,
                    imageName: "Small Image"
                )


            // Discord could have disconnected while an
            // image was being uploaded.
            try validateDiscordConnection()


            // MARK: Timer

            // Custom elapsed starts survive Apply, presets and restoration.
            // Ordinary elapsed/countdown timers still restart from now.
            try presence.applyTimer(at: Date(), restoredExpiration: restoredExpiration)


            // MARK: Discord

            try await discord.updatePresence(
                details: presence.details,
                state: presence.state,
                largeImage: resolvedLargeImage,
                largeImageText:
                    presence.largeImageText,
                smallImage: resolvedSmallImage,
                smallImageText:
                    presence.smallImageText,
                buttons: presence.buttons,
                startTimestamp:
                    presence.startTimestamp,
                endTimestamp:
                    presence.endTimestamp
            )


            // Discord's UpdateRichPresence callback
            // confirmed success. Only now do we consider
            // this configuration active.

            activeAppliedPresence = presence

            replaceAutoDisableScheduleIfNeeded()

            presenceError = nil

            saveLastAppliedPresence()

            print(
                "Presence applied successfully."
            )


            // MARK: Hide After Applying

            guard hideWindowAfterApplying else {
                return
            }

            let hideAfterApplying =
                UserDefaults.standard.bool(
                    forKey:
                        "hideAfterApplyingPresence"
                )

            if hideAfterApplying {
                hideMainWindows()

                print(
                    "Lumaunt main window hidden after applying presence."
                )
            }

        } catch {
            showPresenceError(error)

            print(
                "Failed to apply presence:",
                error.localizedDescription
            )
        }
    }


    // MARK: - Content Moderation

    private func moderatePresenceContent() async throws {

        try await moderatePresenceField(
            presence.details,
            fieldName: "Details"
        )

        try await moderatePresenceField(
            presence.state,
            fieldName: "State"
        )

        try await moderatePresenceField(
            presence.largeImageText,
            fieldName: "Large Image Hover Text"
        )

        try await moderatePresenceField(
            presence.smallImageText,
            fieldName: "Small Image Hover Text"
        )

        for (index, button) in
            presence.buttons.enumerated() {

            try await moderatePresenceField(
                button.label,
                fieldName:
                    "Button \(index + 1) Label"
            )
        }
    }


    private func moderatePresenceField(
        _ text: String,
        fieldName: String
    ) async throws {

        let trimmed =
            text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !trimmed.isEmpty else {
            return
        }


        switch ContentFilter.validate(
            trimmed
        ) {

        case .allowed:
            return


        case .blocked(
            let category,
            let reason
        ):
            throw PresenceApplyError
                .contentBlocked(
                    fieldName: fieldName,
                    category:
                        category.displayName,
                    reason: reason
                )


        case .needsReview(
            let categories
        ):

            var confirmedCategories:
                Set<
                    ContentFilter.ContentCategory
                > = []


            // Layer 1 may identify more than one
            // category for the same field.
            //
            // Review each suspected category
            // independently so the contextual
            // classifier answers exactly the
            // question Layer 1 asked.

            for category in categories {

                let apiCategory =
                    ModerationPolicy.shared
                        .apiCategory(
                            for: category
                        )


                let contextResult =
                    try await ModerationService.shared
                        .moderateContext(
                            text: trimmed,
                            suspectedCategory:
                                apiCategory
                        )


                let decision =
                    ModerationPolicy.shared
                        .evaluate(
                            suspectedCategory:
                                category,
                            contextResult:
                                contextResult
                        )


                switch decision {

                case .allowed:
                    continue


                case .blocked(
                    let categories
                ):
                    confirmedCategories
                        .formUnion(
                            categories
                        )


                case .invalidResponse:
                    throw ModerationServiceError
                        .invalidResponse
                }
            }


            guard
                !confirmedCategories.isEmpty
            else {
                return
            }


            let names =
                confirmedCategories
                    .map {
                        $0.displayName
                    }
                    .sorted()


            throw PresenceApplyError
                .contentReviewBlocked(
                    fieldName:
                        fieldName,
                    categories:
                        names
                )
        }
    }

    // MARK: - Validation

    private func validateDiscordConnection() throws {
        switch discord.connectionState {

        case .connected:
            return

        case .connecting:
            throw PresenceApplyError.connecting

        case .authorizing:
            throw PresenceApplyError.authorizing

        case .discordUnavailable:
            throw PresenceApplyError
                .discordUnavailable

        case .error(let message):
            throw PresenceApplyError
                .discordError(message)

        case .disconnected:
            throw PresenceApplyError.notConnected
        }
    }


    private func validatePresence() throws {

        // MARK: Text Limits

        guard presence.details.count <= 128 else {
            throw PresenceApplyError
                .detailsTooLong
        }

        guard presence.state.count <= 128 else {
            throw PresenceApplyError
                .stateTooLong
        }

        guard
            presence.largeImageText.count <= 128
        else {
            throw PresenceApplyError
                .largeImageTextTooLong
        }

        guard
            presence.smallImageText.count <= 128
        else {
            throw PresenceApplyError
                .smallImageTextTooLong
        }


        // MARK: Timer

        if presence.timerMode == .elapsed && !presence.hasValidCustomStartTime(at: Date()) {
            throw PresenceTimerError.invalidStartTime
        }

        if presence.timerMode == .countdown {
            guard presence.countdownDuration >= 60 else {
                throw PresenceApplyError
                    .invalidCountdown
            }
        }


        // MARK: Buttons

        guard presence.buttons.count <= 2 else {
            throw PresenceApplyError
                .tooManyButtons
        }

        for (index, button) in
            presence.buttons.enumerated() {

            let buttonNumber = index + 1

            let label =
                button.label.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            let urlString =
                button.url.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            guard !label.isEmpty else {
                throw PresenceApplyError
                    .missingButtonLabel(
                        buttonNumber
                    )
            }

            guard label.count <= 32 else {
                throw PresenceApplyError
                    .buttonLabelTooLong(
                        buttonNumber
                    )
            }

            guard !urlString.isEmpty else {
                throw PresenceApplyError
                    .missingButtonURL(
                        buttonNumber
                    )
            }

            guard
                let url = URL(
                    string: urlString
                ),
                let scheme =
                    url.scheme?.lowercased(),
                scheme == "http" ||
                    scheme == "https",
                url.host != nil
            else {
                throw PresenceApplyError
                    .invalidButtonURL(
                        buttonNumber
                    )
            }
        }
    }


    // MARK: - Error Presentation

    @MainActor
    private func showPresenceError(
        _ error: Error
    ) {
        if let localizedError =
            error as? LocalizedError,
           let description =
            localizedError.errorDescription,
           !description.isEmpty {

            presenceError = description

        } else {
            let description =
                error.localizedDescription
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

            presenceError =
                description.isEmpty
                    ? "Something went wrong while applying your presence. Try again."
                    : description
        }
    }


    @MainActor
    func clearPresenceError() {
        presenceError = nil
    }


    // MARK: - Clear Presence

    @MainActor
    func clearPresence(
        allowWhileDisconnected: Bool = false
    ) {

        presenceError = nil
        cancelAutoDisableSchedule(
            removePersistedDeadline: true
        )

        guard
            allowWhileDisconnected ||
            discord.connectionState == .connected
        else {
            do {
                try validateDiscordConnection()
            } catch {
                showPresenceError(error)
            }

            return
        }

        guard discord.hasActivePresence else {
            activeAppliedPresence = nil
            presence.startTimestamp = nil
            presence.endTimestamp = nil

            presenceError =
                "There is no active Lumaunt presence to disable."

            return
        }

        discord.clearPresence()

        presence.startTimestamp = nil
        presence.endTimestamp = nil

        // Nothing is active on Discord anymore.
        activeAppliedPresence = nil

        presenceError = nil
    }


    // MARK: - Countdown Auto-Disable

    @MainActor
    private func replaceAutoDisableScheduleIfNeeded() {
        cancelAutoDisableSchedule(
            removePersistedDeadline: false
        )

        let generation = UUID()
        activePresenceGeneration = generation

        guard
            let appliedPresence = activeAppliedPresence,
            appliedPresence.timerMode == .countdown,
            appliedPresence.disablePresenceWhenTimerEnds,
            let expiration = appliedPresence.endTimestamp
        else {
            return
        }

        autoDisableTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                let remaining = expiration.timeIntervalSinceNow

                if remaining <= 0 {
                    break
                }

                do {
                    try await Task.sleep(
                        for: .seconds(remaining)
                    )
                } catch {
                    return
                }
            }

            guard
                let self,
                !Task.isCancelled,
                self.activePresenceGeneration == generation,
                self.activeAppliedPresence?.endTimestamp == expiration
            else {
                return
            }

            self.clearPresence(
                allowWhileDisconnected: true
            )
        }
    }


    @MainActor
    private func cancelAutoDisableSchedule(
        removePersistedDeadline: Bool
    ) {
        autoDisableTask?.cancel()
        autoDisableTask = nil
        activePresenceGeneration = nil

        guard removePersistedDeadline else {
            return
        }

        removePersistedAutoDisableDeadline()
    }


    private func removePersistedAutoDisableDeadline() {
        guard
            let data = UserDefaults.standard.data(
                forKey: Self.lastPresenceKey
            ),
            var savedPresence = try? JSONDecoder().decode(
                PresenceConfiguration.self,
                from: data
            ),
            savedPresence.disablePresenceWhenTimerEnds,
            savedPresence.endTimestamp != nil
        else {
            return
        }

        savedPresence.endTimestamp = nil

        guard let updatedData = try? JSONEncoder().encode(
            savedPresence
        ) else {
            return
        }

        UserDefaults.standard.set(
            updatedData,
            forKey: Self.lastPresenceKey
        )
    }

    // MARK: - Editor Draft

    private func saveEditorDraft() {
        do {
            var draft = presence

            // Runtime timer values should not become part of
            // the editable draft saved between launches.
            draft.startTimestamp = nil
            draft.endTimestamp = nil

            let data =
                try JSONEncoder()
                    .encode(draft)

            UserDefaults.standard.set(
                data,
                forKey: Self.editorDraftKey
            )

        } catch {
            print(
                "Failed to save presence editor draft:",
                error.localizedDescription
            )
        }
    }


    private func loadEditorDraft() {
        guard
            let data =
                UserDefaults.standard.data(
                    forKey: Self.editorDraftKey
                ),
            let draft =
                try? JSONDecoder().decode(
                    PresenceConfiguration.self,
                    from: data
                )
        else {
            // Existing users may not have a draft yet.
            // Fall back to their last successfully applied
            // presence so upgrading doesn't empty the editor.
            loadLastPresenceIntoEditor()
            return
        }

        isLoadingPersistedPresence = true
        presence = draft
        isLoadingPersistedPresence = false
    }


    // MARK: - Last Presence

    private func saveLastAppliedPresence() {
        do {
            var savedPresence = presence

            // Applied elapsed timestamps and ordinary countdown deadlines
            // are runtime-only. Auto-disable countdowns retain their
            // absolute deadline so launch restoration cannot restart
            // the full duration.
            savedPresence.startTimestamp = nil
            // customStartTime is a saved choice and remains intact.

            if !(
                savedPresence.timerMode == .countdown &&
                savedPresence.disablePresenceWhenTimerEnds
            ) {
                savedPresence.endTimestamp = nil
            }

            let data =
                try JSONEncoder()
                    .encode(savedPresence)

            UserDefaults.standard.set(
                data,
                forKey: Self.lastPresenceKey
            )

        } catch {
            // Saving the convenience restore copy
            // should not turn a successful Discord
            // presence update into a failed Apply.
            print(
                "Failed to save last presence:",
                error.localizedDescription
            )
        }
    }


    private func loadLastPresenceIntoEditor() {
        guard var savedPresence =
            loadLastAppliedPresence()
        else {
            return
        }

        savedPresence.startTimestamp = nil
        savedPresence.endTimestamp = nil

        isLoadingPersistedPresence = true
        presence = savedPresence
        isLoadingPersistedPresence = false
    }


    private func loadLastAppliedPresence()
        -> PresenceConfiguration? {

        guard
            let data =
                UserDefaults.standard.data(
                    forKey: Self.lastPresenceKey
                ),
            let savedPresence =
                try? JSONDecoder().decode(
                    PresenceConfiguration.self,
                    from: data
                )
        else {
            return nil
        }

        return savedPresence
    }

    // MARK: - Automatic Restore

    private func beginAutomaticPresenceRestore() {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            guard let lastAppliedPresence =
                self.loadLastAppliedPresence()
            else {
                print(
                    "No last applied presence is available to restore."
                )
                return
            }

            let restoredExpiration =
                lastAppliedPresence.disablePresenceWhenTimerEnds
                    ? lastAppliedPresence.endTimestamp
                    : nil

            if lastAppliedPresence.disablePresenceWhenTimerEnds {
                guard
                    let restoredExpiration,
                    restoredExpiration > Date()
                else {
                    print(
                        "Last presence was not restored because its countdown expired."
                    )
                    return
                }
            }

            // Preserve whatever the user was editing.
            let editorDraft = self.presence

            // Discord's OAuth/session restoration is
            // asynchronous. Give it time to reach Ready.
            for _ in 0..<120 {

                if self.discord.connectionState ==
                    .connected {

                    if let restoredExpiration,
                       restoredExpiration <= Date() {
                        print(
                            "Last presence was not restored because its countdown expired."
                        )
                        return
                    }

                    print(
                        "Discord connected. Restoring last presence..."
                    )

                    // Temporarily put the last successfully
                    // applied configuration through the normal
                    // Apply pipeline.
                    self.isLoadingPersistedPresence = true
                    self.presence = lastAppliedPresence
                    self.isLoadingPersistedPresence = false

                    await self.applyPresence(
                        hideWindowAfterApplying: false,
                        restoredExpiration: restoredExpiration
                    )

                    // Applying modifies runtime timestamps.
                    // Restore the editor exactly as it was.
                    self.isLoadingPersistedPresence = true
                    self.presence = editorDraft
                    self.isLoadingPersistedPresence = false

                    return
                }

                try? await Task.sleep(
                    for: .milliseconds(250)
                )
            }

            // Automatic restoration happens in the
            // background, so don't surface a banner just
            // because Discord wasn't available at launch.
            print(
                "Last presence was not restored because Discord did not become ready."
            )
        }
    }

    // MARK: - Storage

    func refreshStorageInformation() {
        do {
            localImageStorageSize =
                try localImageStore
                    .storageSize()

            localImageCount =
                try localImageStore
                    .storedImageCount()

            cachedUploadCount =
                imageUploadCache
                    .cachedUploadCount

            storageError = nil

        } catch {
            storageError =
                error.localizedDescription

            print(
                "Failed to read Lumaunt storage:",
                error.localizedDescription
            )
        }
    }


    func clearLocalImageCache() {
        do {
            try localImageStore
                .clearStoredImages()

            try imageUploadCache
                .clear()

            refreshStorageInformation()

        } catch {
            storageError =
                error.localizedDescription

            print(
                "Failed to clear Lumaunt image cache:",
                error.localizedDescription
            )
        }
    }


    // MARK: - Quit Behavior

    private func configureTerminationObserver() {
        terminationObserver =
            NotificationCenter.default.addObserver(
                forName:
                    NSApplication
                        .willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in

                guard
                    UserDefaults.standard.bool(
                        forKey:
                            Self.clearOnQuitKey
                    )
                else {
                    return
                }

                self?.discord.clearPresence()

                print(
                    "Presence cleared because Lumaunt is quitting."
                )
            }
    }


    // MARK: - Window

    private func hideMainWindows() {
        NSApplication.shared.windows
            .filter { window in
                window.canBecomeMain &&
                    window.title != ""
            }
            .forEach { window in
                window.orderOut(nil)
            }
    }


    // MARK: - Image Resolution

    private func resolveImage(
        _ value: String,
        imageName: String
    ) async throws -> String {

        let trimmed =
            value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !trimmed.isEmpty else {
            return ""
        }


        // MARK: Web Image

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" ||
               scheme == "https" {

            guard url.host != nil else {
                throw PresenceApplyError
                    .invalidImageReference(
                        imageName
                    )
            }

            return trimmed
        }


        // MARK: Local Image

        if let url = URL(string: trimmed),
           url.isFileURL {

            guard
                FileManager.default.fileExists(
                    atPath: url.path
                )
            else {
                throw PresenceApplyError
                    .localImageMissing(
                        imageName
                    )
            }

            print(
                "Uploading local image:",
                url.lastPathComponent
            )

            do {
                let uploadedImage =
                    try await imageUploadService
                        .upload(
                            fileURL: url
                        )

                print(
                    "Image uploaded:",
                    uploadedImage
                        .url
                        .absoluteString
                )

                return uploadedImage
                    .url
                    .absoluteString

            } catch {
                throw PresenceApplyError
                    .imageUploadFailed(
                        imageName: imageName,
                        reason:
                            error.localizedDescription
                    )
            }
        }


        // A string containing :// is attempting to
        // specify a URL scheme we don't support.

        if trimmed.contains("://") {
            throw PresenceApplyError
                .unsupportedImageReference(
                    imageName
                )
        }


        // Existing image values may also be Discord
        // asset identifiers rather than URLs. Preserve
        // those instead of incorrectly rejecting them.

        return trimmed
    }
}
