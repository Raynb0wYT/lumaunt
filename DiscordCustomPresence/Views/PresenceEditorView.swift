import SwiftUI

struct PresenceEditorView: View {
    @Bindable var appState: AppState
    @FocusState private var focusedField: String?

    private let maximumTextLength = 128

    private let lumauntGradient = LinearGradient(
        colors: [
            Color(
                red: 0.18,
                green: 0.72,
                blue: 1.0
            ),
            Color(
                red: 0.48,
                green: 0.30,
                blue: 1.0
            )
        ],
        startPoint: .leading,
        endPoint: .trailing
    )


    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 24
            ) {

                // MARK: Header

                header


                // MARK: Workspace

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 24) {
                        editorColumn.frame(minWidth: 300, maxWidth: .infinity)
                        previewColumn.frame(minWidth: 300, maxWidth: 420)
                    }
                    VStack(alignment: .leading, spacing: 24) {
                        editorColumn
                        previewColumn.frame(maxWidth: .infinity)
                    }
                }


                // MARK: Error

                if let error =
                    appState.presenceError {

                    errorBanner(error)
                        .transition(
                            .opacity.combined(
                                with: .move(
                                    edge: .top
                                )
                            )
                        )
                }


                // MARK: Actions

                actionBar
            }
            .padding(28)
        }
        .animation(
            .easeInOut(duration: 0.18),
            value: appState.presenceError
        )
        .onChange(
            of: appState.presence
        ) { _, _ in

            // An error describing the previous editor
            // state is stale as soon as the user changes
            // that state.

            if appState.presenceError != nil &&
                !appState.isApplyingPresence {

                appState.clearPresenceError()
            }
        }
    }


    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text("Presence")
                    .font(
                        .system(
                            size: 28,
                            weight: .bold
                        )
                    )
                    .accessibilityAddTraits(.isHeader)

                Text(
                    "Create and preview your Discord Rich Presence."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Spacer()

            connectionBadge
        }
    }


    // MARK: - Editor

    private var editorColumn: some View {
        VStack(
            alignment: .leading,
            spacing: 20
        ) {
            sectionHeader(
                title: "Presence Details",
                subtitle:
                    "Customize what Discord displays."
            )

            VStack(
                alignment: .leading,
                spacing: 16
            ) {

                lumauntTextField(
                    title: "Details",
                    placeholder:
                        "What are you doing?",
                    text:
                        $appState.presence.details,
                    count:
                        appState.presence
                            .details.count
                )

                lumauntTextField(
                    title: "State",
                    placeholder:
                        "Add some context",
                    text:
                        $appState.presence.state,
                    count:
                        appState.presence
                            .state.count
                )

                Divider()


                // MARK: Timer

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {
                    Text("Timer")
                        .fontWeight(.medium)

                    Picker(
                        "Timer",
                        selection:
                            $appState.presence
                                .timerMode
                    ) {
                        Text("Elapsed Time")
                            .tag(
                                PresenceTimerMode
                                    .elapsed
                            )

                        Text("Countdown")
                            .tag(
                                PresenceTimerMode
                                    .countdown
                            )
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel("Timer mode")
                    .accessibilityHint(
                        "Choose between elapsed time and countdown."
                    )


                    if appState.presence
                        .timerMode == .countdown {

                        countdownEditor

                    } else {
                        elapsedTimerEditor
                    }
                }
            }
            .padding(18)
            .background {
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .fill(
                    .quaternary.opacity(
                        0.28
                    )
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .stroke(
                    .quaternary,
                    lineWidth: 1
                )
            }
        }
    }


    // MARK: - Elapsed Time

    private var usesCustomStartTime: Binding<Bool> {
        Binding(
            get: { appState.presence.customStartTime != nil },
            set: { enabled in
                appState.presence.customStartTime = enabled ? Date() : nil
                appState.presence.startTimestamp = nil
            }
        )
    }

    private var customStartTime: Binding<Date> {
        Binding(
            get: { appState.presence.customStartTime ?? Date() },
            set: { appState.presence.customStartTime = $0 }
        )
    }

    private var elapsedTimerEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Use a custom start time", isOn: usesCustomStartTime)
                .accessibilityHint("Count elapsed time from a date and time you choose.")

            if appState.presence.customStartTime != nil {
                DatePicker(
                    "Started at",
                    selection: customStartTime,
                    in: Date(timeIntervalSince1970: 0)...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.field)
                .accessibilityLabel("Elapsed timer start date and time")
                Text("Elapsed time starts from this date, even when you apply again. Presets keep the chosen date.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !appState.presence.hasValidCustomStartTime(at: Date()) {
                    Text("Choose a start time between January 1, 1970 and now.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } else {
                Text("Discord will show how long the presence has been active. Applying starts the timer from now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Countdown

    private var countdownEditor: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            HStack(spacing: 16) {
                Text("Duration")
                    .foregroundStyle(
                        .secondary
                    )

                Spacer()

                Stepper(
                    value: countdownHours,
                    in: 0...23
                ) {
                    Text(
                        "\(countdownHours.wrappedValue) hr"
                    )
                    .monospacedDigit()
                    .frame(
                        minWidth: 42,
                        alignment: .trailing
                    )
                }
                .accessibilityLabel("Countdown hours")
                .accessibilityValue(
                    "\(countdownHours.wrappedValue) hours"
                )

                Stepper(
                    value: countdownMinutes,
                    in: 0...59
                ) {
                    Text(
                        "\(countdownMinutes.wrappedValue) min"
                    )
                    .monospacedDigit()
                    .frame(
                        minWidth: 50,
                        alignment: .trailing
                    )
                }
                .accessibilityLabel("Countdown minutes")
                .accessibilityValue(
                    "\(countdownMinutes.wrappedValue) minutes"
                )
            }

            if countdownIsInvalid {
                HStack(spacing: 5) {
                    Image(
                        systemName:
                            "exclamationmark.circle.fill"
                    )

                    Text(
                        "Countdown must be at least 1 minute."
                    )
                }
                .font(.caption)
                .foregroundStyle(.red)

            } else {
                Text(
                    "Discord will count down from this duration when the presence is applied."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Toggle(
                "Disable presence when timer ends",
                isOn: $appState.presence
                    .disablePresenceWhenTimerEnds
            )
            .accessibilityHint(
                "Automatically clears the applied Discord presence when this countdown finishes."
            )
        }
    }


    // MARK: - Preview

    private var previewColumn: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            sectionHeader(
                title: "Live Preview",
                subtitle:
                    "Updates instantly as you make changes."
            )

            ZStack {
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(
                    .quaternary.opacity(
                        0.18
                    )
                )

                VStack(spacing: 0) {
                    lumauntGradient
                        .frame(height: 3)

                    PresencePreviewView(
                        presence:
                            appState.presence
                    )
                    .padding(18)
                }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    .quaternary,
                    lineWidth: 1
                )
            }
        }
    }


    // MARK: - Actions

    private var actionBar: some View {
        HStack(spacing: 10) {

            if appState.discord
                .hasActivePresence {

                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(
                            width: 7,
                            height: 7
                        )

                    Text("Presence active")
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                }
            }

            Spacer()


            // MARK: Disable

            Button {
                appState.clearPresence()
            } label: {
                Label(
                    "Disable",
                    systemImage:
                        "stop.circle"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(
                !appState.discord
                    .hasActivePresence ||
                appState.isApplyingPresence
            )
            .help(disableHelpText)



            // MARK: Apply

            Button {
                Task {
                    await appState
                        .applyPresence()
                }
            } label: {
                HStack(spacing: 7) {

                    if appState
                        .isApplyingPresence {

                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)

                        Text("Applying…")

                    } else if appState
                        .isCurrentPresenceApplied {

                        Image(
                            systemName:
                                "checkmark"
                        )

                        Text("Applied")

                    } else {
                        Image(
                            systemName:
                                "sparkles"
                        )

                        Text("Apply Presence")
                    }
                }
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(
                    .horizontal,
                    16
                )
                .frame(height: 34)
                .background {
                    RoundedRectangle(
                        cornerRadius: 8,
                        style: .continuous
                    )
                    .fill(lumauntGradient)
                }
            }
            .buttonStyle(.plain)
            .disabled(applyButtonDisabled)
            .opacity(
                applyButtonDisabled
                    ? 0.5
                    : 1
            )
            .help(applyHelpText)

        }
        .padding(.top, 4)
    }


    // MARK: - Apply State

    private var applyButtonDisabled: Bool {

        if appState.isApplyingPresence {
            return true
        }

        switch appState.discord
            .connectionState {

        case .authorizing,
             .connecting:
            return true

        case .connected,
             .disconnected,
             .discordUnavailable,
             .error:
            return false
        }
    }


    private var applyHelpText: String {

        if appState.isApplyingPresence {
            return
                "Lumaunt is applying your presence."
        }

        switch appState.discord
            .connectionState {

        case .connected:
            if appState
                .isCurrentPresenceApplied {

                return
                    "This presence is currently applied to Discord."
            }

            return
                "Apply this presence to Discord"

        case .authorizing:
            return
                "Finish Discord authorization first"

        case .connecting:
            return
                "Wait for Lumaunt to finish connecting to Discord"

        case .discordUnavailable:
            return
                "Discord is unavailable. Click to see more information."

        case .error:
            return
                "Discord encountered a connection error. Click to see more information."

        case .disconnected:
            return
                "Discord is not connected. Click to see more information."
        }
    }


    private var disableHelpText: String {
        if appState.isApplyingPresence {
            return
                "Wait for the current Apply operation to finish."
        }

        if appState.discord
            .hasActivePresence {

            return
                "Disable the active Lumaunt presence."
        }

        return
            "There is no active Lumaunt presence to disable."
    }


    // MARK: - Connection Badge

    private var connectionBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionColor)
                .frame(
                    width: 7,
                    height: 7
                )

            Text(connectionText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(
            .horizontal,
            10
        )
        .padding(
            .vertical,
            6
        )
        .background {
            Capsule()
                .fill(
                    .quaternary.opacity(
                        0.35
                    )
                )
        }
        .help(connectionHelpText)
    }


    private var connectionText: String {
        switch appState.discord
            .connectionState {

        case .connected:
            return "Discord Connected"

        case .connecting:
            return "Connecting"

        case .authorizing:
            return "Authorizing"

        case .discordUnavailable:
            return "Discord Offline"

        case .error:
            return "Connection Error"

        case .disconnected:
            return "Not Connected"
        }
    }


    private var connectionColor: Color {
        switch appState.discord
            .connectionState {

        case .connected:
            return .green

        case .connecting,
             .authorizing:
            return .orange

        case .discordUnavailable,
             .error:
            return .red

        case .disconnected:
            return .secondary
        }
    }


    private var connectionHelpText: String {
        switch appState.discord
            .connectionState {

        case .connected:
            return
                "Lumaunt is connected to Discord."

        case .connecting:
            return
                "Lumaunt is connecting to Discord."

        case .authorizing:
            return
                "Discord authorization is in progress."

        case .discordUnavailable:
            return
                "The Discord desktop app is currently unavailable."

        case .error(let message):
            let trimmed =
                message.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            return trimmed.isEmpty
                ? "Lumaunt encountered a Discord connection error."
                : trimmed

        case .disconnected:
            return
                "Lumaunt is not connected to Discord."
        }
    }


    // MARK: - Text Field

    private func lumauntTextField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        count: Int
    ) -> some View {

        let isInvalid =
            count > maximumTextLength

        return VStack(
            alignment: .leading,
            spacing: 7
        ) {
            HStack {
                Text(title)
                    .fontWeight(.medium)

                Spacer()

                Text(
                    "\(count) / \(maximumTextLength)"
                )
                .font(.caption2)
                .foregroundStyle(
                    isInvalid
                        ? .red
                        : .secondary
                )
                .monospacedDigit()
            }

            TextField(
                placeholder,
                text: text
            )
            .accessibilityLabel(title)
            .focused($focusedField, equals: title)
            .onSubmit { focusedField = title == "Details" ? "State" : nil }
            .textFieldStyle(.plain)
            .padding(
                .horizontal,
                11
            )
            .frame(height: 36)
            .background {
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
                .fill(
                    Color(
                        nsColor:
                            .controlBackgroundColor
                    )
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
                .stroke(
                    isInvalid
                        ? Color.red
                            .opacity(0.8)
                        : Color.secondary
                            .opacity(0.18),
                    lineWidth: 1
                )
            }

            if isInvalid {
                HStack(spacing: 5) {
                    Image(
                        systemName:
                            "exclamationmark.circle.fill"
                    )

                    Text(
                        "\(title) must be \(maximumTextLength) characters or fewer."
                    )
                }
                .font(.caption)
                .foregroundStyle(.red)
            }
        }
    }


    // MARK: - Countdown Bindings

    private var countdownHours: Binding<Int> {
        Binding(
            get: {
                Int(
                    appState.presence
                        .countdownDuration
                ) / 3600
            },
            set: { newHours in

                let totalSeconds =
                    Int(
                        appState.presence
                            .countdownDuration
                    )

                let minutes =
                    (totalSeconds % 3600) /
                    60

                appState.presence
                    .countdownDuration =
                    TimeInterval(
                        newHours * 3600 +
                        minutes * 60
                    )
            }
        )
    }


    private var countdownMinutes: Binding<Int> {
        Binding(
            get: {
                let totalSeconds =
                    Int(
                        appState.presence
                            .countdownDuration
                    )

                return
                    (totalSeconds % 3600) /
                    60
            },
            set: { newMinutes in

                let hours =
                    Int(
                        appState.presence
                            .countdownDuration
                    ) / 3600

                appState.presence
                    .countdownDuration =
                    TimeInterval(
                        hours * 3600 +
                        newMinutes * 60
                    )
            }
        )
    }


    private var countdownIsInvalid: Bool {
        appState.presence.timerMode ==
            .countdown &&
        appState.presence
            .countdownDuration < 60
    }


    // MARK: - Section Header

    private func sectionHeader(
        title: String,
        subtitle: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 3
        ) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }


    // MARK: - Error

    private func errorBanner(
        _ message: String
    ) -> some View {

        HStack(
            alignment: .top,
            spacing: 10
        ) {
            Image(
                systemName:
                    "exclamationmark.triangle.fill"
            )
            .padding(.top, 1)

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text("Couldn't Apply Presence")
                    .fontWeight(.semibold)

                Text(message)
                    .font(.callout)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }

            Spacer(minLength: 12)

            Button {
                withAnimation(
                    .easeInOut(
                        duration: 0.18
                    )
                ) {
                    appState
                        .clearPresenceError()
                }
            } label: {
                Image(
                    systemName: "xmark"
                )
                .font(
                    .system(
                        size: 11,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width: 24,
                    height: 24
                )
                .contentShape(
                    Rectangle()
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss presence error")
            .help("Dismiss")
        }
        .foregroundStyle(.red)
        .padding(12)
        .background {
            RoundedRectangle(
                cornerRadius: 10,
                style: .continuous
            )
            .fill(
                Color.red.opacity(
                    0.08
                )
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 10,
                style: .continuous
            )
            .stroke(
                Color.red.opacity(
                    0.16
                ),
                lineWidth: 1
            )
        }
    }
}
