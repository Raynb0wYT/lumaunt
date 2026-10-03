import Foundation
import Security

struct ManagedImage: Codable, Identifiable, Equatable {
    var id: String { key }
    let key: String
    let url: URL
    let expiresAt: Date
}

@MainActor @Observable
final class HostedImageStore {
    static let shared = HostedImageStore()
    private(set) var images: [ManagedImage] = []
    var isDeleting = false
    var message: String?
    private let fileURL: URL

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = support.appendingPathComponent("Lumaunt/managed-images.json")
        if let data = try? Data(contentsOf: fileURL),
           let stored = try? JSONDecoder().decode([ManagedImage].self, from: data) { images = stored }
    }

    func record(_ image: UploadedImage) throws {
        guard let expiration = image.expiresAt else { throw ImageUploadError.invalidResponse }
        let record = ManagedImage(key: image.key, url: image.url, expiresAt: Date(timeIntervalSince1970: expiration / 1000))
        if !images.contains(where: { $0.key == record.key }) { images.append(record) }
        try save()
    }

    func deleteAll() async -> [URL] {
        guard !isDeleting else { return [] }
        isDeleting = true
        defer { isDeleting = false }
        var deleted: [URL] = []
        message = nil
        for image in images {
            do {
                try await ImageUploadService().delete(image: image)
                images.removeAll { $0.key == image.key }
                try ImageUploadCache.shared.remove(objectKey: image.key)
                try save()
                deleted.append(image.url)
            } catch {
                message = "Some images could not be deleted: \(error.localizedDescription) Try again to finish."
            }
        }
        if message == nil { message = "Hosted images deleted. Your local image files are kept." }
        return deleted
    }

    private func save() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(images).write(to: fileURL, options: .atomic)
    }
}

enum ImagePrivacySettings {
    static var uploadsAllowed: Bool { UserDefaults.standard.bool(forKey: "allowHostedImageUploads") }
    static var retentionDays: Int {
        let value = UserDefaults.standard.integer(forKey: "hostedImageRetentionDays")
        return [7, 30, 90].contains(value) ? value : 30
    }

    static func ownerToken() throws -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                  kSecAttrService as String: "app.lumaunt.image-management",
                                  kSecAttrAccount as String: "installation"]
        var result: CFTypeRef?
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data,
           let token = String(data: data, encoding: .utf8) { return token }
        guard status == errSecItemNotFound else {
            throw ImageUploadError.serverError("Lumaunt could not access its image-management key in Keychain.")
        }
        let token = UUID().uuidString + UUID().uuidString
        var item = query
        item[kSecValueData as String] = Data(token.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
            throw ImageUploadError.serverError("Lumaunt could not save its image-management key in Keychain.")
        }
        return token
    }
}
