import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ClipboardImageControl: View {
    let title: String
    let onImport: (URL) -> Void
    let onError: (String) -> Void

    var body: some View {
        Button {
            importClipboardImage()
        } label: {
            Label("Paste Image", systemImage: "doc.on.clipboard")
        }
        .accessibilityLabel("Paste clipboard image into \(title)")
        .help("Copy an image, then click here or focus this button and press ⌘V.")
        .focusable()
        .onPasteCommand(of: [.image]) { providers in
            // Image-only paste belongs to this focused destination. Text fields
            // keep their standard text paste behavior.
            guard !providers.isEmpty else { return }
            importClipboardImage()
        }
    }

    private func importClipboardImage() {
        if let fileURL = copiedImageFileURL() {
            importImage(at: fileURL)
            return
        }

        guard let image = NSImage(pasteboard: .general),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            onError("The clipboard does not contain an image. Copy an image first.")
            return
        }

        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        defer { try? FileManager.default.removeItem(at: temporary) }

        do {
            try png.write(to: temporary, options: .atomic)
            importImage(at: temporary)
        } catch {
            onError(error.localizedDescription)
        }
    }

    private func copiedImageFileURL() -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: [UTType.image.identifier]
        ]

        return (NSPasteboard.general.readObjects(
            forClasses: [NSURL.self],
            options: options
        ) as? [URL])?.first
    }

    private func importImage(at url: URL) {
        do {
            try ImageValidator.validateDimensions(of: url)
            onImport(try LocalImageStore.shared.importImage(from: url))
        } catch {
            onError(error.localizedDescription)
        }
    }
}
