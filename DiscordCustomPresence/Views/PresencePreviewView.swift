import SwiftUI
import Combine

struct PresencePreviewView: View {
    let presence: PresenceConfiguration

    @State private var currentTime = Date()

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

                            Text(elapsedTimeText)
                                .monospacedDigit()
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    }

                    Spacer(minLength: 0)
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
                                Color(nsColor: .windowBackgroundColor),
                                lineWidth: 3
                            )
                    }
                    .offset(
                        x: 4,
                        y: 4
                    )
            }
        }
        .frame(
            width: 94,
            height: 94,
            alignment: .topLeading
        )
    }

    // MARK: - Large Image

    @ViewBuilder
    private var largeArtwork: some View {
        if let url = imageURL(
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
        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard
            !trimmed.isEmpty,
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" ||
            scheme == "https" ||
            scheme == "file"
        else {
            return nil
        }

        return url
    }

    // MARK: - Timer

    private var elapsedTimeText: String {
        guard let start = presence.startTimestamp else {
            return "0:00"
        }

        let elapsed = max(
            0,
            Int(
                currentTime.timeIntervalSince(start)
            )
        )

        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60

        if hours > 0 {
            return String(
                format: "%d:%02d:%02d",
                hours,
                minutes,
                seconds
            )
        }

        return String(
            format: "%d:%02d",
            minutes,
            seconds
        )
    }
}
