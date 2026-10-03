import SwiftUI
import Combine

struct PresencePreviewView: View {
    let presence: PresenceConfiguration

    @State private var currentTime = Date()
    @State private var hoveredArtwork: HoveredArtwork?

    private enum HoveredArtwork {
        case large
        case small
    }

    private let timer = Timer.publish(
        every: 1,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // MARK: Preview Label

            Text("DISCORD PREVIEW")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            // MARK: Discord Card

            VStack(alignment: .leading, spacing: 14) {

                HStack {
                    Text("Playing")
                        .font(.system(size: 14))

                    Spacer()

                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 14) {
                    artwork

                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {
                        Text("Lumaunt")
                            .font(
                                .system(
                                    size: 15,
                                    weight: .semibold
                                )
                            )
                            .lineLimit(1)

                        if !presence.details.isEmpty {
                            Text(presence.details)
                                .font(.system(size: 14))
                                .lineLimit(1)
                        }

                        if !presence.state.isEmpty {
                            Text(presence.state)
                                .font(.system(size: 14))
                                .lineLimit(1)
                        }

                        HStack(spacing: 5) {
                            Image(
                                systemName: "gamecontroller.fill"
                            )
                            .font(.system(size: 11))

                            Text(timerText)
                                .monospacedDigit()
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    }

                    Spacer(minLength: 0)
                }

                if !presence.buttons.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(
                            Array(
                                presence.buttons
                                    .prefix(2)
                                    .enumerated()
                            ),
                            id: \.offset
                        ) { _, button in
                            if !button.label
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )
                                .isEmpty {

                                HStack {
                                    Spacer()

                                    Text(button.label)
                                        .font(
                                            .system(
                                                size: 13,
                                                weight: .medium
                                            )
                                        )
                                        .lineLimit(1)

                                    Spacer()
                                }
                                .frame(height: 32)
                                .background {
                                    RoundedRectangle(
                                        cornerRadius: 4,
                                        style: .continuous
                                    )
                                    .fill(
                                        Color.secondary
                                            .opacity(0.14)
                                    )
                                }
                                .overlay {
                                    RoundedRectangle(
                                        cornerRadius: 4,
                                        style: .continuous
                                    )
                                    .stroke(
                                        Color.secondary
                                            .opacity(0.12),
                                        lineWidth: 1
                                    )
                                }
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .background(.quaternary.opacity(0.45))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
            )
        }
        .onReceive(timer) { time in
            currentTime = time
        }
    }

    // MARK: - Artwork

    private var artwork: some View {
        ZStack(alignment: .bottomTrailing) {

            // MARK: Large Artwork

            largeArtwork
                .frame(
                    width: 90,
                    height: 90
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                )
                .accessibilityLabel("Large image")
                .accessibilityValue(
                    presence.largeImageText
                )

            // MARK: Small Artwork

            if !presence.smallImage.isEmpty {
                smallArtwork
                    .frame(
                        width: 28,
                        height: 28
                    )
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(
                                Color(
                                    nsColor:
                                        .windowBackgroundColor
                                ),
                                lineWidth: 3
                            )
                    }
                    .offset(
                        x: 4,
                        y: 4
                    )
                    .accessibilityLabel("Small image")
                    .accessibilityValue(
                        presence.smallImageText
                    )
            }

            // MARK: Stable Hover Regions

            RoundedRectangle(
                cornerRadius: 10,
                style: .continuous
            )
            .fill(Color.clear)
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
            )
            .frame(
                width: 90,
                height: 90
            )
            .onHover { isHovering in
                if isHovering {
                    hoveredArtwork = .large
                } else if hoveredArtwork == .large {
                    hoveredArtwork = nil
                }
            }

            if !presence.smallImage.isEmpty {
                Circle()
                    .fill(Color.clear)
                    .contentShape(Circle())
                    .frame(
                        width: 28,
                        height: 28
                    )
                    .offset(
                        x: 4,
                        y: 4
                    )
                    .onHover { isHovering in
                        if isHovering {
                            hoveredArtwork = .small
                        } else if hoveredArtwork == .small {
                            hoveredArtwork = nil
                        }
                    }
            }
        }
        .frame(
            width: 94,
            height: 94,
            alignment: .topLeading
        )
        .overlay(
            alignment: .top
        ) {
            if let tooltipText = hoveredTooltipText {
                artworkTooltip(tooltipText)
                    .fixedSize()
                    .offset(y: -38)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Hover Tooltip

    private var hoveredTooltipText: String? {
        let text: String

        switch hoveredArtwork {
        case .large:
            text = presence.largeImageText

        case .small:
            text = presence.smallImageText

        case nil:
            return nil
        }

        let trimmed = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmed.isEmpty ? nil : trimmed
    }

    private func artworkTooltip(
        _ text: String
    ) -> some View {
        Text(text)
            .font(
                .system(
                    size: 12,
                    weight: .medium
                )
            )
            .foregroundStyle(.white)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
            .frame(maxWidth: 180)
            .padding(
                .horizontal,
                9
            )
            .padding(
                .vertical,
                6
            )
            .background {
                RoundedRectangle(
                    cornerRadius: 5,
                    style: .continuous
                )
                .fill(
                    Color.black.opacity(0.92)
                )
            }
            .shadow(
                radius: 4,
                y: 2
            )
    }

    // MARK: - Large Image

    @ViewBuilder
    private var largeArtwork: some View {
        if let url = imageURL(
            from: presence.largeImage
        ),
           url.isFileURL,
           let image = NSImage(
            contentsOf: url
           ) {

            Image(nsImage: image)
                .resizable()
                .scaledToFill()

        } else if let url = imageURL(
            from: presence.largeImage
        ) {

            AsyncImage(url: url) { phase in
                switch phase {

                case .empty:
                    imagePlaceholder(
                        systemName: "photo"
                    )
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                    }

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()

                case .failure:
                    imagePlaceholder(
                        systemName:
                            "exclamationmark.triangle"
                    )

                @unknown default:
                    imagePlaceholder(
                        systemName: "photo"
                    )
                }
            }

        } else {
            imagePlaceholder(
                systemName: "questionmark"
            )
        }
    }

    // MARK: - Small Image

    @ViewBuilder
    private var smallArtwork: some View {
        if let url = imageURL(
            from: presence.smallImage
        ),
           url.isFileURL,
           let image = NSImage(
            contentsOf: url
           ) {

            Image(nsImage: image)
                .resizable()
                .scaledToFill()

        } else if let url = imageURL(
            from: presence.smallImage
        ) {

            AsyncImage(url: url) { phase in
                switch phase {

                case .empty:
                    Circle()
                        .fill(.quaternary)

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()

                case .failure:
                    Circle()
                        .fill(.quaternary)
                        .overlay {
                            Image(
                                systemName:
                                    "exclamationmark"
                            )
                            .font(.caption2)
                        }

                @unknown default:
                    Circle()
                        .fill(.quaternary)
                }
            }

        } else {
            Circle()
                .fill(.quaternary)
        }
    }

    // MARK: - Placeholder

    private func imagePlaceholder(
        systemName: String
    ) -> some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(
                    systemName: systemName
                )
                .font(
                    .system(
                        size: 30,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.secondary)
            }
    }

    // MARK: - URL Validation

    private func imageURL(
        from value: String
    ) -> URL? {
        let trimmed = value
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard
            !trimmed.isEmpty,
            let url = URL(string: trimmed),
            let scheme =
                url.scheme?.lowercased(),
            scheme == "http" ||
                scheme == "https" ||
                scheme == "file"
        else {
            return nil
        }

        return url
    }

    // MARK: - Timer

    private var timerText: String {
        switch presence.timerMode {

        case .elapsed:
            return elapsedTimeText

        case .countdown:
            return countdownTimeText
        }
    }

    private var elapsedTimeText: String {
        guard let start =
            presence.customStartTime ?? presence.startTimestamp
        else {
            return "0:00 elapsed"
        }

        let elapsed = max(
            0,
            Int(
                currentTime
                    .timeIntervalSince(start)
            )
        )

        return formattedTime(
            seconds: elapsed,
            suffix: "elapsed"
        )
    }

    private var countdownTimeText: String {
        let remaining: Int

        if let end =
            presence.endTimestamp {

            remaining = max(
                0,
                Int(
                    end.timeIntervalSince(
                        currentTime
                    )
                )
            )

        } else {
            remaining = max(
                0,
                Int(
                    presence
                        .countdownDuration
                )
            )
        }

        return formattedTime(
            seconds: remaining,
            suffix: "remaining"
        )
    }

    private func formattedTime(
        seconds: Int,
        suffix: String
    ) -> String {
        let hours = seconds / 3600
        let minutes =
            (seconds % 3600) / 60
        let remainingSeconds =
            seconds % 60

        let time: String

        if hours > 0 {
            time = String(
                format: "%d:%02d:%02d",
                hours,
                minutes,
                remainingSeconds
            )
        } else {
            time = String(
                format: "%d:%02d",
                minutes,
                remainingSeconds
            )
        }

        return "\(time) \(suffix)"
    }
}
