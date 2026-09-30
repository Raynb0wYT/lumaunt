import Foundation

enum LocalImageStoreError: LocalizedError {
    case unableToAccessFile
    case unableToCreateStorage

    var errorDescription: String? {
        switch self {
        case .unableToAccessFile:
            return "Lumaunt could not access the selected image."
        case .unableToCreateStorage:
            return "Lumaunt could not create its local image storage."
        }
    }
}

final class LocalImageStore {
    static let shared = LocalImageStore()

    private let fileManager = FileManager.default

    private init() {}

    func importImage(from sourceURL: URL) throws -> URL {
        let accessing = sourceURL.startAccessingSecurityScopedResource()

        defer {
            if accessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw LocalImageStoreError.unableToAccessFile
        }

        let imagesDirectory = try imagesDirectory()

        let fileExtension = sourceURL.pathExtension.lowercased()

        let destinationURL = imagesDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)

        do {
            try fileManager.copyItem(
                at: sourceURL,
                to: destinationURL
            )

            return destinationURL
        } catch {
            print("Local image import failed:", error)
            throw LocalImageStoreError.unableToAccessFile
        }
    }

    private func imagesDirectory() throws -> URL {
        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw LocalImageStoreError.unableToCreateStorage
        }

        let directory = applicationSupport
            .appendingPathComponent("Lumaunt", isDirectory: true)
            .appendingPathComponent("Images", isDirectory: true)

        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )

            return directory
        } catch {
            throw LocalImageStoreError.unableToCreateStorage
        }
    }
}
