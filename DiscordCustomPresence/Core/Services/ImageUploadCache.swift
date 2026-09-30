import Foundation
import CryptoKit

final class ImageUploadCache {

    static let shared = ImageUploadCache()

    private struct CacheEntry: Codable {
        let url: String
        let objectKey: String
    }

    private var entries: [String: CacheEntry] = [:]

    private let fileManager = FileManager.default

    private init() {
        load()
    }


    // MARK: - Lookup

    func uploadedImage(
        for fileURL: URL
    ) throws -> UploadedImage? {

        let hash = try hashFile(
            at: fileURL
        )

        guard let entry = entries[hash],
              let url = URL(string: entry.url)
        else {
            return nil
        }

        print(
            "Image upload cache hit:",
            fileURL.lastPathComponent
        )

        return UploadedImage(
            id: hash,
            key: entry.objectKey,
            url: url
        )
    }


    // MARK: - Store

    func store(
        _ uploadedImage: UploadedImage,
        for fileURL: URL
    ) throws {

        let hash = try hashFile(
            at: fileURL
        )

        entries[hash] = CacheEntry(
            url: uploadedImage.url.absoluteString,
            objectKey: uploadedImage.key
        )

        try save()

        print(
            "Image saved to upload cache:",
            fileURL.lastPathComponent
        )
    }


    // MARK: - Hashing

    private func hashFile(
        at url: URL
    ) throws -> String {

        let data = try Data(
            contentsOf: url
        )

        let digest = SHA256.hash(
            data: data
        )

        return digest
            .map {
                String(
                    format: "%02x",
                    $0
                )
            }
            .joined()
    }


    // MARK: - Persistence

    private func cacheFileURL() throws -> URL {

        guard let applicationSupport =
                fileManager.urls(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask
                ).first
        else {
            throw CocoaError(
                .fileNoSuchFile
            )
        }

        let directory = applicationSupport
            .appendingPathComponent(
                "Lumaunt",
                isDirectory: true
            )

        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory
            .appendingPathComponent(
                "image-upload-cache.json"
            )
    }


    private func load() {

        do {
            let url = try cacheFileURL()

            guard fileManager.fileExists(
                atPath: url.path
            ) else {
                return
            }

            let data = try Data(
                contentsOf: url
            )

            entries = try JSONDecoder()
                .decode(
                    [String: CacheEntry].self,
                    from: data
                )

            print(
                "Loaded \(entries.count) cached image upload(s)."
            )

        } catch {
            print(
                "Failed to load image upload cache:",
                error
            )

            entries = [:]
        }
    }


    private func save() throws {

        let url = try cacheFileURL()

        let data = try JSONEncoder()
            .encode(entries)

        try data.write(
            to: url,
            options: .atomic
        )
    }
}
