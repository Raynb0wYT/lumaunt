import SwiftUI
import UniformTypeIdentifiers

struct ImagesView: View {
    @Bindable var appState: AppState

    @State private var selectingLargeImage = false
    @State private var selectingSmallImage = false

    @State private var largeImageDropTarget = false
    @State private var smallImageDropTarget = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                header

                Divider()

                imageSection(
                    title: "Large Image",
                    description: "The main artwork displayed on your Discord presence.",
                    imageValue: $appState.presence.largeImage,
                    hoverText: $appState.presence.largeImageText,
                    isSelectingFile: $selectingLargeImage,
                    isDropTarget: $largeImageDropTarget,
                    previewSize: 120
                )

                Divider()

                imageSection(
                    title: "Small Image",
                    description: "Optional artwork displayed over the corner of the large image.",
                    imageValue: $appState.presence.smallImage,
                    hoverText: $appState.presence.smallImageText,
                    isSelectingFile: $selectingSmallImage,
                    isDropTarget: $smallImageDropTarget,
                    previewSize: 72
                )
            }
            .padding(24)
            .frame(maxWidth: 700, alignment: .leading)
        }
        .navigationTitle("Images")
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Presence Images")
                .font(.title2)
                .fontWeight(.semibold)

            Text(
                "Configure the artwork displayed with your Discord Rich Presence."
            )
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Image Section

    private func imageSection(
        title: String,
        description: String,
        imageValue: Binding<String>,
        hoverText: Binding<String>,
        isSelectingFile: Binding<Bool>,
        isDropTarget: Binding<Bool>,
        previewSize: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 18) {

                // Image preview + drag/drop target
                imagePreview(
                    value: imageValue.wrappedValue,
                    size: previewSize
                )
                .overlay {
                    if isDropTarget.wrappedValue {
                        RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                        .strokeBorder(
                            .tint,
                            lineWidth: 3
                        )
                    }
                }
                .onDrop(
                    of: [.fileURL],
                    isTargeted: isDropTarget
                ) { providers in
                    handleDrop(
                        providers,
                        imageValue: imageValue
                    )
                }

                // Image controls
                VStack(alignment: .leading, spacing: 12) {

                    TextField(
                        "Image URL",
                        text: imageValue
                    )
                    .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Choose File…") {
                            isSelectingFile.wrappedValue = true
                        }

                        if !imageValue.wrappedValue.isEmpty {
                            Button("Remove") {
                                imageValue.wrappedValue = ""
                            }
                        }
                    }

                    TextField(
                        "Hover Text",
                        text: hoverText
                    )
                    .textFieldStyle(.roundedBorder)

                    if isLocalFile(imageValue.wrappedValue) {
                        Label(
                            "Local image selected.",
                            systemImage: "checkmark.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: isSelectingFile,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(
                result,
                imageValue: imageValue
            )
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private func imagePreview(
        value: String,
        size: CGFloat
    ) -> some View {
        if let url = imageURL(from: value) {
            AsyncImage(url: url) { phase in
                switch phase {

                case .empty:
                    previewPlaceholder(size: size)
                        .overlay {
                            ProgressView()
                                .controlSize(.small)
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
                    previewPlaceholder(size: size)
                        .overlay {
                            Image(
                                systemName: "exclamationmark.triangle"
                            )
                        }

                @unknown default:
                    previewPlaceholder(size: size)
                }
            }
        } else {
            previewPlaceholder(size: size)
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
            Image(systemName: "photo")
                .font(
                    .system(size: size * 0.28)
                )
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - File Importer

    private func handleFileSelection(
        _ result: Result<[URL], Error>,
        imageValue: Binding<String>
    ) {
        switch result {

        case .success(let urls):
            guard let sourceURL = urls.first else {
                return
            }

            guard isSupportedImage(sourceURL) else {
                print("Unsupported image type.")
                return
            }

            do {
                let managedURL = try LocalImageStore.shared.importImage(
                    from: sourceURL
                )

                imageValue.wrappedValue =
                    managedURL.absoluteString

                print(
                    "Imported local image:",
                    managedURL.path
                )
            } catch {
                print(
                    "Failed to import image:",
                    error.localizedDescription
                )
            }

        case .failure(let error):
            print(
                "Failed to select image:",
                error.localizedDescription
            )
        }
    }

    // MARK: - Drag and Drop

    private func handleDrop(
        _ providers: [NSItemProvider],
        imageValue: Binding<String>
    ) -> Bool {
        guard let provider = providers.first else {
            return false
        }

        provider.loadItem(
            forTypeIdentifier: UTType.fileURL.identifier,
            options: nil
        ) { item, error in

            if let error {
                print(
                    "Failed to load dropped image:",
                    error.localizedDescription
                )
                return
            }

            var droppedURL: URL?

            if let data = item as? Data {
                droppedURL = URL(
                    dataRepresentation: data,
                    relativeTo: nil
                )
            } else if let url = item as? URL {
                droppedURL = url
            }

            guard let droppedURL else {
                print("Could not read dropped file URL.")
                return
            }

            guard isSupportedImage(droppedURL) else {
                print("Unsupported image type.")
                return
            }

            do {
                let managedURL = try LocalImageStore.shared.importImage(
                    from: droppedURL
                )

                DispatchQueue.main.async {
                    imageValue.wrappedValue =
                        managedURL.absoluteString

                    print(
                        "Imported dropped image:",
                        managedURL.path
                    )
                }
            } catch {
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
        guard let type = UTType(
            filenameExtension: url.pathExtension
        ) else {
            return false
        }

        return type.conforms(to: .image)
    }

    // MARK: - URL Helpers

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

    private func isLocalFile(
        _ value: String
    ) -> Bool {
        guard let url = URL(string: value) else {
            return false
        }

        return url.isFileURL
    }
}
