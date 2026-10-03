import SwiftUI

struct ButtonsView: View {
    @Bindable var appState: AppState

    private func moveButton(at index: Int, by offset: Int) {
        let destination = index + offset
        guard appState.presence.buttons.indices.contains(index),
              appState.presence.buttons.indices.contains(destination) else { return }
        appState.presence.buttons.swapAt(index, destination)
    }
    private let maximumButtons = 2
    private let maximumLabelLength = 32

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
                spacing: 28
            ) {
                header

                if appState.presence.buttons.isEmpty {
                    emptyState
                } else {
                    buttonsEditor
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 28)
            .frame(
                maxWidth: 900,
                alignment: .leading
            )
        }
        .onChange(
            of: appState.presence.buttons
        ) { _, _ in
            if appState.presenceError != nil &&
                !appState.isApplyingPresence {

                appState.clearPresenceError()
            }
        }
    }


    // MARK: - Header

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 5
        ) {
            Text("Buttons")
                .font(
                    .system(
                        size: 28,
                        weight: .bold
                    )
                )
                .accessibilityAddTraits(.isHeader)

            Text(
                "Add links people can open directly from your Discord presence."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }


    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        Color.secondary
                            .opacity(0.08)
                    )
                    .frame(
                        width: 64,
                        height: 64
                    )

                Image(
                    systemName:
                        "rectangle.and.hand.point.up.left"
                )
                .font(
                    .system(
                        size: 26,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    AnyShapeStyle(
                        lumauntGradient
                    )
                )
            }

            VStack(spacing: 5) {
                Text("Add a presence button")
                    .font(.headline)

                Text(
                    "Give people a link they can open directly from your presence."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            Button {
                addButton()
            } label: {
                Label(
                    "Add Button",
                    systemImage: "plus"
                )
                .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("You can add up to 2 buttons.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 300
        )
        .padding(24)
        .background {
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .fill(
                .quaternary.opacity(0.20)
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


    // MARK: - Buttons Editor

    private var buttonsEditor: some View {
        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            HStack {
                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text("Presence Buttons")
                        .font(.headline)

                    Text(
                        "Configure up to two links shown on your presence."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(
                    "\(appState.presence.buttons.count) / \(maximumButtons)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }

            ForEach(
                Array(
                    appState.presence
                        .buttons.indices
                ),
                id: \.self
            ) { index in
                buttonCard(index: index)
            }

            if appState.presence.buttons.count <
                maximumButtons {

                Button {
                    addButton()
                } label: {
                    Label(
                        "Add Another Button",
                        systemImage: "plus"
                    )
                }
                .buttonStyle(.bordered)

            } else {
                HStack(spacing: 6) {
                    Image(
                        systemName:
                            "checkmark.circle"
                    )

                    Text(
                        "Maximum of 2 buttons reached."
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }


    // MARK: - Button Card

    private func buttonCard(
        index: Int
    ) -> some View {

        let labelBinding =
            Binding<String>(
                get: {
                    guard
                        appState.presence
                            .buttons.indices
                            .contains(index)
                    else {
                        return ""
                    }

                    return appState.presence
                        .buttons[index]
                        .label
                },
                set: { newValue in
                    guard
                        appState.presence
                            .buttons.indices
                            .contains(index)
                    else {
                        return
                    }

                    appState.presence
                        .buttons[index]
                        .label =
                        newValue
                }
            )


        let urlBinding =
            Binding<String>(
                get: {
                    guard
                        appState.presence
                            .buttons.indices
                            .contains(index)
                    else {
                        return ""
                    }

                    return appState.presence
                        .buttons[index]
                        .url
                },
                set: { newValue in
                    guard
                        appState.presence
                            .buttons.indices
                            .contains(index)
                    else {
                        return
                    }

                    appState.presence
                        .buttons[index]
                        .url =
                        newValue
                }
            )


        let label =
            labelBinding.wrappedValue
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        let url =
            urlBinding.wrappedValue
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        let labelIsEmpty =
            label.isEmpty

        let labelIsTooLong =
            labelBinding.wrappedValue.count >
            maximumLabelLength

        let urlIsEmpty =
            url.isEmpty

        let urlIsInvalid =
            !urlIsEmpty &&
            !isValidURL(url)


        return VStack(
            alignment: .leading,
            spacing: 18
        ) {

            // MARK: Card Header

            HStack {
                HStack(spacing: 9) {
                    ZStack {
                        RoundedRectangle(
                            cornerRadius: 7,
                            style: .continuous
                        )
                        .fill(
                            Color.secondary
                                .opacity(0.10)
                        )
                        .frame(
                            width: 30,
                            height: 30
                        )

                        Image(
                            systemName: "link"
                        )
                        .font(
                            .system(
                                size: 13,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Text(
                        "Button \(index + 1)"
                    )
                    .font(.headline)
                }

                Spacer()

                Button { moveButton(at: index, by: -1) } label: { Image(systemName: "arrow.up") }
                    .disabled(index == 0)
                    .accessibilityLabel("Move button \(index + 1) up")
                    .help("Move up")
                Button { moveButton(at: index, by: 1) } label: { Image(systemName: "arrow.down") }
                    .disabled(index == appState.presence.buttons.count - 1)
                    .accessibilityLabel("Move button \(index + 1) down")
                    .help("Move down")
                Button(role: .destructive) {
                    removeButton(at: index)
                } label: {
                    Label(
                        "Remove",
                        systemImage: "trash"
                    )
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove button \(index + 1)")
            }

            Divider()


            // MARK: Label

            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                HStack {
                    Text("Label")
                        .fontWeight(.medium)

                    Spacer()

                    Text(
                        "\(labelBinding.wrappedValue.count) / \(maximumLabelLength)"
                    )
                    .font(.caption2)
                    .foregroundStyle(
                        labelIsTooLong
                            ? .red
                            : .secondary
                    )
                    .monospacedDigit()
                }

                TextField(
                    "View Website",
                    text: labelBinding
                )
                .accessibilityLabel("Button \(index + 1) label")
                .textFieldStyle(.plain)
                .padding(.horizontal, 11)
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
                        labelIsEmpty ||
                        labelIsTooLong
                            ? Color.red
                                .opacity(0.8)
                            : Color.secondary
                                .opacity(0.18),
                        lineWidth: 1
                    )
                }

                if labelIsEmpty {
                    validationMessage(
                        "Button \(index + 1) needs a label."
                    )

                } else if labelIsTooLong {
                    validationMessage(
                        "Button \(index + 1) label must be \(maximumLabelLength) characters or fewer."
                    )

                } else {
                    Text(
                        "This is the text people will see on the button."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }


            // MARK: URL

            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                HStack {
                    Text("URL")
                        .fontWeight(.medium)

                    Spacer()

                    if !urlIsEmpty {
                        urlStatus(
                            urlBinding
                                .wrappedValue
                        )
                    }
                }

                TextField(
                    "https://example.com",
                    text: urlBinding
                )
                .accessibilityLabel("Button \(index + 1) URL")
                .textFieldStyle(.plain)
                .padding(.horizontal, 11)
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
                        urlIsEmpty ||
                        urlIsInvalid
                            ? Color.red
                                .opacity(0.8)
                            : Color.secondary
                                .opacity(0.18),
                        lineWidth: 1
                    )
                }

                if urlIsEmpty {
                    validationMessage(
                        "Button \(index + 1) needs a URL."
                    )

                } else if urlIsInvalid {
                    validationMessage(
                        "Enter a valid http:// or https:// URL."
                    )

                } else {
                    Text(
                        "Enter a complete http:// or https:// link."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
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
                .quaternary.opacity(0.28)
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .stroke(
                buttonHasValidationError(
                    index: index
                )
                    ? Color.red.opacity(0.22)
                    : Color.secondary.opacity(0.12),
                lineWidth: 1
            )
        }
    }


    // MARK: - Validation Message

    private func validationMessage(
        _ message: String
    ) -> some View {
        HStack(spacing: 5) {
            Image(
                systemName:
                    "exclamationmark.circle.fill"
            )

            Text(message)
        }
        .font(.caption)
        .foregroundStyle(.red)
    }


    // MARK: - URL Status

    @ViewBuilder
    private func urlStatus(
        _ value: String
    ) -> some View {
        if isValidURL(value) {
            Label(
                "Valid URL",
                systemImage:
                    "checkmark.circle.fill"
            )
            .font(.caption)
            .foregroundStyle(.green)

        } else {
            Label(
                "Invalid URL",
                systemImage:
                    "exclamationmark.circle.fill"
            )
            .font(.caption)
            .foregroundStyle(.red)
        }
    }


    // MARK: - Actions

    private func addButton() {
        guard
            appState.presence.buttons.count <
                maximumButtons
        else {
            return
        }

        appState.presence.buttons.append(
            PresenceButton()
        )

        appState.clearPresenceError()
    }


    private func removeButton(
        at index: Int
    ) {
        guard
            appState.presence.buttons
                .indices.contains(index)
        else {
            return
        }

        withAnimation(
            .easeInOut(duration: 0.18)
        ) {
            appState.presence.buttons
                .remove(at: index)
        }

        appState.clearPresenceError()
    }


    // MARK: - Validation

    private func buttonHasValidationError(
        index: Int
    ) -> Bool {
        guard
            appState.presence.buttons
                .indices.contains(index)
        else {
            return false
        }

        let button =
            appState.presence
                .buttons[index]

        let label =
            button.label
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        let url =
            button.url
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        if label.isEmpty {
            return true
        }

        if button.label.count >
            maximumLabelLength {

            return true
        }

        if url.isEmpty {
            return true
        }

        return !isValidURL(url)
    }


    private func isValidURL(
        _ value: String
    ) -> Bool {
        let trimmed =
            value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard
            let url =
                URL(string: trimmed),
            let scheme =
                url.scheme?.lowercased(),
            scheme == "http" ||
                scheme == "https",
            url.host != nil
        else {
            return false
        }

        return true
    }
}
