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


    // MARK: - Import

    func importImage(
        from sourceURL: URL
    ) throws -> URL {
        let accessing =
            sourceURL.startAccessingSecurityScopedResource()

        defer {
            if accessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard fileManager.fileExists(
            atPath: sourceURL.path
        ) else {
            throw LocalImageStoreError.unableToAccessFile
        }

        let imagesDirectory =
            try imagesDirectory()

        let fileExtension =
            sourceURL.pathExtension.lowercased()

        let destinationURL =
            imagesDirectory
                .appendingPathComponent(
                    UUID().uuidString
                )
                .appendingPathExtension(
                    fileExtension
                )

        do {
            try fileManager.copyItem(
                at: sourceURL,
                to: destinationURL
            )

            return destinationURL

        } catch {
            print(
                "Local image import failed:",
                error
            )

            throw LocalImageStoreError
                .unableToAccessFile
        }
    }


    // MARK: - Storage Information

    func storageSize() throws -> Int64 {
        let directory =
            try imagesDirectory()

        guard let enumerator =
            fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .fileSizeKey
                ],
                options: [
                    .skipsHiddenFiles
                ]
            )
        else {
            return 0
        }

        var totalSize: Int64 = 0

        for case let fileURL as URL in enumerator {
            let values =
                try? fileURL.resourceValues(
                    forKeys: [
                        .isRegularFileKey,
                        .fileSizeKey
                    ]
                )

            guard
                values?.isRegularFile == true,
                let fileSize = values?.fileSize
            else {
                continue
            }

            totalSize += Int64(fileSize)
        }

        return totalSize
    }


    func storedImageCount() throws -> Int {
        let directory =
            try imagesDirectory()

        let contents =
            try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [
                    .isRegularFileKey
                ],
                options: [
                    .skipsHiddenFiles
                ]
            )

        return contents.reduce(0) {
            result,
            fileURL in

            let values =
                try? fileURL.resourceValues(
                    forKeys: [
                        .isRegularFileKey
                    ]
                )

            return result +
                (values?.isRegularFile == true
                    ? 1
                    : 0)
        }
    }


    // MARK: - Clear Storage

    func clearStoredImages() throws {
        let directory =
            try imagesDirectory()

        let contents =
            try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: []
            )

        for fileURL in contents {
            try fileManager.removeItem(
                at: fileURL
            )
        }

        print(
            "Cleared local Lumaunt image storage."
        )
    }


    // MARK: - Directory

    private func imagesDirectory() throws -> URL {
        guard let applicationSupport =
            fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
        else {
            throw LocalImageStoreError
                .unableToCreateStorage
        }

        let directory =
            applicationSupport
                .appendingPathComponent(
                    "Lumaunt",
                    isDirectory: true
                )
                .appendingPathComponent(
                    "Images",
                    isDirectory: true
                )

        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )

            return directory

        } catch {
            throw LocalImageStoreError
                .unableToCreateStorage
        }
    }
}
