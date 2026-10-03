import SwiftUI
import UniformTypeIdentifiers

struct ImagesView: View {
    @Bindable var appState: AppState

    @State private var selectingLargeImage = false
    @State private var selectingSmallImage = false

    @State private var largeImageDropTarget = false
    @State private var smallImageDropTarget = false

    @State private var showLargeURL = false
    @State private var showSmallURL = false

    @State private var imageError: String?

    private let maximumHoverTextLength = 128

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
                ImagePrivacyView(appState: appState)

                if let imageError {
                    errorBanner(imageError)
                        .transition(
                            .opacity.combined(
                                with: .move(
                                    edge: .top
                                )
                            )
                        )
                }

                imageCard(
                    title: "Large Image",
                    description:
                        "The main artwork displayed on your Discord presence.",
                    imageValue:
                        $appState.presence.largeImage,
                    hoverText:
                        $appState.presence.largeImageText,
                    isSelectingFile:
                        $selectingLargeImage,
                    isDropTarget:
                        $largeImageDropTarget,
                    showURL:
                        $showLargeURL,
                    previewSize: 150,
                    isLargeImage: true
                )

                imageCard(
                    title: "Small Image",
                    description:
                        "Optional artwork displayed over the corner of the large image.",
                    imageValue:
                        $appState.presence.smallImage,
                    hoverText:
                        $appState.presence.smallImageText,
                    isSelectingFile:
                        $selectingSmallImage,
                    isDropTarget:
                        $smallImageDropTarget,
                    showURL:
                        $showSmallURL,
                    previewSize: 92,
                    isLargeImage: false
                )
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
            .padding(.top, 22)
            .frame(
                maxWidth: 900,
                alignment: .leading
            )
        }
        .animation(
            .easeInOut(duration: 0.18),
            value: imageError
        )
        .onChange(
            of: appState.presence.largeImage
        ) { _, _ in
            clearStaleErrors()
        }
        .onChange(
            of: appState.presence.smallImage
        ) { _, _ in
            clearStaleErrors()
        }
        .onChange(
            of: appState.presence.largeImageText
        ) { _, _ in
            clearStaleErrors()
        }
        .onChange(
            of: appState.presence.smallImageText
        ) { _, _ in
            clearStaleErrors()
        }
    }


    // MARK: - Header

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 5
        ) {
            Text("Images")
                .font(
                    .system(
                        size: 28,
                        weight: .bold
                    )
                )
                .accessibilityAddTraits(.isHeader)

            Text(
                "Customize the artwork displayed with your Discord Rich Presence."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }


    // MARK: - Image Card

    private func imageCard(
        title: String,
        description: String,
        imageValue: Binding<String>,
        hoverText: Binding<String>,
        isSelectingFile: Binding<Bool>,
        isDropTarget: Binding<Bool>,
        showURL: Binding<Bool>,
        previewSize: CGFloat,
        isLargeImage: Bool
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)

                    if !imageValue
                        .wrappedValue.isEmpty {

                        Label(
                            isLocalFile(
                                imageValue
                                    .wrappedValue
                            )
                                ? "Local"
                                : "URL",
                            systemImage:
                                isLocalFile(
                                    imageValue
                                        .wrappedValue
                                )
                                    ? "internaldrive"
                                    : "link"
                        )
                        .font(.caption2)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
            }

            VStack(
                alignment: .leading,
                spacing: 16
            ) {
                if imageValue
                    .wrappedValue.isEmpty {

                    emptyImageDropZone(
                        imageValue:
                            imageValue,
                        isSelectingFile:
                            isSelectingFile,
                        isDropTarget:
                            isDropTarget,
                        showURL:
                            showURL,
                        isLargeImage:
                            isLargeImage
                    )

                } else {
                    selectedImageArea(
                        imageValue:
                            imageValue,
                        isSelectingFile:
                            isSelectingFile,
                        isDropTarget:
                            isDropTarget,
                        previewSize:
                            previewSize,
                        imageName:
                            title
                    )
                }

                if showURL.wrappedValue {
                    urlEditor(
                        imageValue:
                            imageValue,
                        showURL:
                            showURL,
                        imageName: title
                    )
                }

                ClipboardImageControl(title: title) { url in
                    imageValue.wrappedValue = url.absoluteString
                    appState.clearPresenceError()
                } onError: { message in imageError = message }
                Divider()

                hoverTextField(
                    text: hoverText,
                    imageName: title
                )
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
                    hoverText.wrappedValue
                        .count >
                        maximumHoverTextLength
                        ? Color.red
                            .opacity(0.22)
                        : Color.secondary
                            .opacity(0.12),
                    lineWidth: 1
                )
            }
        }
        .fileImporter(
            isPresented:
                isSelectingFile,
            allowedContentTypes:
                [.image],
            allowsMultipleSelection:
                false
        ) { result in
            handleFileSelection(
                result,
                imageValue:
                    imageValue,
                imageName:
                    title
            )
        }
    }


    // MARK: - Empty Drop Zone

    private func emptyImageDropZone(
        imageValue: Binding<String>,
        isSelectingFile: Binding<Bool>,
        isDropTarget: Binding<Bool>,
        showURL: Binding<Bool>,
        isLargeImage: Bool
    ) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        isDropTarget
                            .wrappedValue
                            ? Color
                                .accentColor
                                .opacity(0.12)
                            : Color
                                .secondary
                                .opacity(0.08)
                    )
                    .frame(
                        width: 48,
                        height: 48
                    )

                Image(
                    systemName:
                        isDropTarget
                            .wrappedValue
                            ? "arrow.down.doc.fill"
                            : "photo.badge.plus"
                )
                .font(
                    .system(
                        size: 21,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    isDropTarget
                        .wrappedValue
                        ? AnyShapeStyle(
                            lumauntGradient
                        )
                        : AnyShapeStyle(
                            Color.secondary
                        )
                )
            }

            VStack(spacing: 4) {
                Text(
                    isDropTarget
                        .wrappedValue
                        ? "Drop image here"
                        : isLargeImage
                            ? "Add your main artwork"
                            : "Add a small image"
                )
                .fontWeight(.medium)

                Text(
                    "Drag and drop an image, or choose one from your Mac."
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )
            }

            HStack(spacing: 8) {
                Button {
                    imageError = nil

                    isSelectingFile
                        .wrappedValue =
                        true
                } label: {
                    Label(
                        "Choose Image",
                        systemImage:
                            "folder"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button {
                    imageError = nil

                    withAnimation(
                        .easeInOut(
                            duration: 0.18
                        )
                    ) {
                        showURL
                            .wrappedValue
                            .toggle()
                    }
                } label: {
                    Label(
                        "Use Image URL",
                        systemImage:
                            "link"
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight:
                isLargeImage
                    ? 145
                    : 120
        )
        .padding(
            .vertical,
            isLargeImage
                ? 12
                : 10
        )
        .padding(
            .horizontal,
            16
        )
        .background {
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .fill(
                isDropTarget
                    .wrappedValue
                    ? Color
                        .accentColor
                        .opacity(0.06)
                    : Color.clear
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .strokeBorder(
                isDropTarget
                    .wrappedValue
                    ? AnyShapeStyle(
                        lumauntGradient
                    )
                    : AnyShapeStyle(
                        Color.secondary
                            .opacity(0.22)
                    ),
                style: StrokeStyle(
                    lineWidth:
                        isDropTarget
                            .wrappedValue
                            ? 2
                            : 1,
                    dash: [6, 5]
                )
            )
        }
        .contentShape(Rectangle())
        .onDrop(
            of: [.fileURL],
            isTargeted:
                isDropTarget
        ) { providers in
            handleDrop(
                providers,
                imageValue:
                    imageValue,
                imageName:
                    isLargeImage
                        ? "Large Image"
                        : "Small Image"
            )
        }
    }


    // MARK: - Selected Image

    private func selectedImageArea(
        imageValue: Binding<String>,
        isSelectingFile: Binding<Bool>,
        isDropTarget: Binding<Bool>,
        previewSize: CGFloat,
        imageName: String
    ) -> some View {
        HStack(
            alignment: .center,
            spacing: 16
        ) {
            imagePreview(
                value:
                    imageValue
                        .wrappedValue,
                size:
                    previewSize
            )
            .accessibilityLabel("\(imageName) preview")
            .overlay {
                if isDropTarget
                    .wrappedValue {

                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                    .strokeBorder(
                        lumauntGradient,
                        lineWidth: 3
                    )
                }
            }
            .onDrop(
                of: [.fileURL],
                isTargeted:
                    isDropTarget
            ) { providers in
                handleDrop(
                    providers,
                    imageValue:
                        imageValue,
                    imageName:
                        imageName
                )
            }

            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text(
                        imageDisplayName(
                            imageValue
                                .wrappedValue
                        )
                    )
                    .fontWeight(.medium)
                    .lineLimit(1)

                    Label(
                        isLocalFile(
                            imageValue
                                .wrappedValue
                        )
                            ? "Stored locally by Lumaunt"
                            : "Using an image URL",
                        systemImage:
                            isLocalFile(
                                imageValue
                                    .wrappedValue
                            )
                                ? "checkmark.circle.fill"
                                : "link"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

                HStack(spacing: 8) {
                    Button {
                        imageError = nil

                        isSelectingFile
                            .wrappedValue =
                            true
                    } label: {
                        Label(
                            "Replace",
                            systemImage:
                                "arrow.triangle.2.circlepath"
                        )
                    }
                    .buttonStyle(.bordered)

                    Button(
                        role: .destructive
                    ) {
                        imageError = nil

                        imageValue
                            .wrappedValue = ""

                        appState
                            .clearPresenceError()

                    } label: {
                        Label(
                            "Remove",
                            systemImage:
                                "trash"
                        )
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()
        }
    }


    // MARK: - URL Editor

    private func urlEditor(
        imageValue: Binding<String>,
        showURL: Binding<Bool>,
        imageName: String
    ) -> some View {
        let value =
            imageValue.wrappedValue
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let hasValue =
            !value.isEmpty

        let valid =
            isValidWebImageURL(
                value
            )

        return VStack(
            alignment: .leading,
            spacing: 7
        ) {
            HStack {
                Text("Image URL")
                    .fontWeight(.medium)

                Spacer()

                if hasValue {
                    if valid {
                        Label(
                            "Valid URL",
                            systemImage:
                                "checkmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .green
                        )

                    } else {
                        Label(
                            "Invalid URL",
                            systemImage:
                                "exclamationmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .red
                        )
                    }
                }

                Button {
                    withAnimation(
                        .easeInOut(
                            duration: 0.18
                        )
                    ) {
                        showURL
                            .wrappedValue =
                            false
                    }
                } label: {
                    Image(
                        systemName:
                            "xmark"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close image URL editor")
                .help(
                    "Close URL editor"
                )
            }

            TextField(
                "https://example.com/image.png",
                text:
                    imageValue
            )
            .accessibilityLabel("\(imageName) image URL")
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
                    hasValue && !valid
                        ? Color.red
                            .opacity(0.8)
                        : Color.secondary
                            .opacity(0.18),
                    lineWidth: 1
                )
            }

            if hasValue && !valid {
                validationMessage(
                    "Enter a valid http:// or https:// image URL."
                )

            } else {
                Text(
                    "Use a direct HTTP or HTTPS link to an image."
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }


    // MARK: - Hover Text

    private func hoverTextField(
        text: Binding<String>,
        imageName: String
    ) -> some View {
        let isInvalid =
            text.wrappedValue.count >
            maximumHoverTextLength

        return VStack(
            alignment: .leading,
            spacing: 7
        ) {
            HStack {
                Text("Hover Text")
                    .fontWeight(.medium)

                Spacer()

                Text(
                    "\(text.wrappedValue.count) / \(maximumHoverTextLength)"
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
                "Shown when someone hovers over the image",
                text: text
            )
            .accessibilityLabel("\(imageName) hover text")
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
                validationMessage(
                    "\(imageName) hover text must be \(maximumHoverTextLength) characters or fewer."
                )
            }
        }
    }


    // MARK: - Validation Message

    private func validationMessage(
        _ message: String
    ) -> some View {
        HStack(
            alignment: .firstTextBaseline,
            spacing: 5
        ) {
            Image(
                systemName:
                    "exclamationmark.circle.fill"
            )

            Text(message)
        }
        .font(.caption)
        .foregroundStyle(.red)
    }


    // MARK: - Preview

    @ViewBuilder
    private func imagePreview(
        value: String,
        size: CGFloat
    ) -> some View {
        if let url =
            imageURL(from: value) {

            AsyncImage(
                url: url
            ) { phase in
                switch phase {

                case .empty:
                    previewPlaceholder(
                        size: size
                    )
                    .overlay {
                        ProgressView()
                            .controlSize(
                                .small
                            )
                    }

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: size,
                            height: size
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 12,
                                style: .continuous
                            )
                        )
                        .clipped()

                case .failure:
                    previewPlaceholder(
                        size: size
                    )
                    .overlay {
                        VStack(spacing: 5) {
                            Image(
                                systemName:
                                    "exclamationmark.triangle"
                            )

                            Text(
                                "Unable to load"
                            )
                            .font(.caption2)
                        }
                        .foregroundStyle(
                            .secondary
                        )
                    }

                @unknown default:
                    previewPlaceholder(
                        size: size
                    )
                }
            }

        } else {
            previewPlaceholder(
                size: size
            )
        }
    }


    private func previewPlaceholder(
        size: CGFloat
    ) -> some View {
        RoundedRectangle(
            cornerRadius: 12,
            style: .continuous
        )
        .fill(.quaternary)
        .frame(
            width: size,
            height: size
        )
        .overlay {
            Image(
                systemName: "photo"
            )
            .font(
                .system(
                    size: size * 0.25
                )
            )
            .foregroundStyle(
                .secondary
            )
        }
    }


    // MARK: - File Importer

    private func handleFileSelection(
        _ result: Result<[URL], Error>,
        imageValue: Binding<String>,
        imageName: String
    ) {
        imageError = nil

        switch result {

        case .success(let urls):
            guard let sourceURL =
                urls.first
            else {
                imageError =
                    "\(imageName) wasn't selected. Try choosing the image again."

                return
            }

            guard
                isSupportedImage(
                    sourceURL
                )
            else {
                imageError =
                    "\(imageName) uses an unsupported file type. Choose a valid image file."

                return
            }

            do {
                let managedURL =
                    try LocalImageStore
                        .shared
                        .importImage(
                            from: sourceURL
                        )

                imageValue
                    .wrappedValue =
                    managedURL
                        .absoluteString

                appState
                    .clearPresenceError()

                print(
                    "Imported local image:",
                    managedURL.path
                )

            } catch {
                imageError =
                    "\(imageName) couldn't be imported: \(error.localizedDescription)"

                print(
                    "Failed to import image:",
                    error.localizedDescription
                )
            }


        case .failure(let error):
            imageError =
                "\(imageName) couldn't be selected: \(error.localizedDescription)"

            print(
                "Failed to select image:",
                error.localizedDescription
            )
        }
    }


    // MARK: - Drag and Drop

    private func handleDrop(
        _ providers: [NSItemProvider],
        imageValue: Binding<String>,
        imageName: String
    ) -> Bool {
        imageError = nil

        guard let provider =
            providers.first
        else {
            imageError =
                "No image was found in the drop."

            return false
        }

        provider.loadItem(
            forTypeIdentifier:
                UTType.fileURL.identifier,
            options: nil
        ) { item, error in

            if let error {
                DispatchQueue.main.async {
                    imageError =
                        "\(imageName) couldn't be read from the drop: \(error.localizedDescription)"
                }

                print(
                    "Failed to load dropped image:",
                    error.localizedDescription
                )

                return
            }

            var droppedURL: URL?

            if let data =
                item as? Data {

                droppedURL =
                    URL(
                        dataRepresentation:
                            data,
                        relativeTo: nil
                    )

            } else if let url =
                item as? URL {

                droppedURL = url
            }

            guard let droppedURL else {
                DispatchQueue.main.async {
                    imageError =
                        "\(imageName) couldn't be read from the dropped item."
                }

                print(
                    "Could not read dropped file URL."
                )

                return
            }

            guard
                isSupportedImage(
                    droppedURL
                )
            else {
                DispatchQueue.main.async {
                    imageError =
                        "\(imageName) uses an unsupported file type. Drop a valid image file instead."
                }

                print(
                    "Unsupported image type."
                )

                return
            }

            do {
                let managedURL =
                    try LocalImageStore
                        .shared
                        .importImage(
                            from:
                                droppedURL
                        )

                DispatchQueue.main.async {
                    imageValue
                        .wrappedValue =
                        managedURL
                            .absoluteString

                    imageError = nil

                    appState
                        .clearPresenceError()

                    print(
                        "Imported dropped image:",
                        managedURL.path
                    )
                }

            } catch {
                DispatchQueue.main.async {
                    imageError =
                        "\(imageName) couldn't be imported: \(error.localizedDescription)"
                }

                print(
                    "Failed to import dropped image:",
                    error.localizedDescription
                )
            }
        }

        return true
    }


    // MARK: - Validation

    private func isSupportedImage(
        _ url: URL
    ) -> Bool {
        guard
            let type = UTType(
                filenameExtension:
                    url.pathExtension
            )
        else {
            return false
        }

        return type.conforms(
            to: .image
        )
    }


    private func isValidWebImageURL(
        _ value: String
    ) -> Bool {
        let trimmed =
            value.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard
            !trimmed.isEmpty,
            let url =
                URL(string: trimmed),
            let scheme =
                url.scheme?
                    .lowercased(),
            scheme == "http" ||
                scheme == "https",
            url.host != nil
        else {
            return false
        }

        return true
    }


    // MARK: - Helpers

    private func imageURL(
        from value: String
    ) -> URL? {
        let trimmed =
            value.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard
            !trimmed.isEmpty,
            let url =
                URL(string: trimmed),
            let scheme =
                url.scheme?
                    .lowercased(),
            scheme == "http" ||
                scheme == "https" ||
                scheme == "file"
        else {
            return nil
        }

        return url
    }


    private func isLocalFile(
        _ value: String
    ) -> Bool {
        guard
            let url =
                URL(string: value)
        else {
            return false
        }

        return url.isFileURL
    }


    private func imageDisplayName(
        _ value: String
    ) -> String {
        guard
            let url =
                URL(string: value)
        else {
            return "Image"
        }

        if url.isFileURL {
            let name =
                url.lastPathComponent

            return name.isEmpty
                ? "Local Image"
                : name
        }

        if let host = url.host,
           !host.isEmpty {

            return host
        }

        return "Image URL"
    }


    private func clearStaleErrors() {
        imageError = nil

        if appState.presenceError != nil &&
            !appState.isApplyingPresence {

            appState.clearPresenceError()
        }
    }


    // MARK: - Error Banner

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
                Text("Image Error")
                    .fontWeight(
                        .semibold
                    )

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
                    imageError = nil
                }
            } label: {
                Image(
                    systemName:
                        "xmark"
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
            .accessibilityLabel("Dismiss image error")
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
                Color.red
                    .opacity(0.08)
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 10,
                style: .continuous
            )
            .stroke(
                Color.red
                    .opacity(0.16),
                lineWidth: 1
            )
        }
    }
}
