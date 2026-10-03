import Foundation

struct UploadedImage: Codable, Equatable {
    let id: String
    let key: String
    let url: URL
    var expiresAt: Double? = nil
}

enum ImageUploadError: LocalizedError {
    case invalidFile
    case unsupportedImageType
    case fileTooLarge
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "The selected image could not be read."

        case .unsupportedImageType:
            return "Only PNG, JPEG, and WebP images are supported."

        case .fileTooLarge:
            return "The image exceeds the 5 MB upload limit."

        case .invalidResponse:
            return "Lumaunt received an invalid response from the image server."

        case .serverError(let message):
            return message
        }
    }
}

final class ImageUploadService {

    private let uploadCache = ImageUploadCache.shared

    // TEMPORARY development endpoint.
    // Later this becomes https://api.lumaunt.app
    private let apiBaseURL = URL(
        string: "https://api.lumaunt.app"
    )!

    private let maximumFileSize = 5 * 1024 * 1024


    // MARK: - Upload

    @MainActor
    func upload(
        fileURL: URL
    ) async throws -> UploadedImage {

        guard ImagePrivacySettings.uploadsAllowed else {
            throw ImageUploadError.serverError("Allow hosted image uploads in Image Privacy before applying a local image, or use an existing image URL.")
        }
        guard fileURL.isFileURL else {
            throw ImageUploadError.invalidFile
        }
        try ImageValidator.validateDimensions(
            of: fileURL
        )
        // Check whether these exact image bytes
        // have already been uploaded.
        if let cachedImage = try uploadCache.uploadedImage(
            for: fileURL
        ), let expiration = cachedImage.expiresAt,
           expiration > Date().timeIntervalSince1970 * 1000 + 60_000 {
            print(
                "Reusing cached image:",
                cachedImage.url.absoluteString
            )

            return cachedImage
        }

        let didAccess =
        fileURL.startAccessingSecurityScopedResource()

        defer {
            if didAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let optimizedImage: OptimizedImage

        do {
            optimizedImage = try ImageOptimizer.optimize(
                fileURL: fileURL
            )
        } catch {
            throw error
        }

        guard !optimizedImage.data.isEmpty else {
            throw ImageUploadError.invalidFile
        }

        guard optimizedImage.data.count <= maximumFileSize else {
            throw ImageUploadError.fileTooLarge
        }

        let data = optimizedImage.data
        let contentType = optimizedImage.contentType
        let uploadURL = apiBaseURL
            .appendingPathComponent("v2/images")
            .appendingPathComponent("upload")

        var request = URLRequest(
            url: uploadURL
        )

        request.httpMethod = "POST"

        request.setValue(
            contentType,
            forHTTPHeaderField: "Content-Type"
        )

        request.setValue(try ImagePrivacySettings.ownerToken(), forHTTPHeaderField: "X-Lumaunt-Owner")
        request.setValue(String(ImagePrivacySettings.retentionDays), forHTTPHeaderField: "X-Lumaunt-Retention-Days")
        request.httpBody = data

        let responseData: Data
        let response: URLResponse

        do {
            (responseData, response) =
            try await URLSession.shared.data(
                for: request
            )
        } catch {
            throw error
        }

        guard let httpResponse =
                response as? HTTPURLResponse
                else {
            throw ImageUploadError.invalidResponse
        }

        guard (200...299).contains(
            httpResponse.statusCode
        ) else {

            if let serverResponse =
                try? JSONDecoder().decode(
                    ServerErrorResponse.self,
                    from: responseData
                ) {

                throw ImageUploadError.serverError(
                    serverResponse.error
                )
            }

            throw ImageUploadError.serverError(
                "Image upload failed with HTTP \(httpResponse.statusCode)."
            )
        }

        do {
            let uploadedImage =
            try JSONDecoder().decode(
                UploadedImage.self,
                from: responseData
            )

            guard uploadedImage.expiresAt != nil else {
                throw ImageUploadError.serverError("The image backend needs the privacy update before new images can be uploaded.")
            }
            try HostedImageStore.shared.record(uploadedImage)
            try uploadCache.store(
                uploadedImage,
                for: fileURL
            )

            print(
                "Uploaded and cached image:",
                uploadedImage.url.absoluteString
            )

            return uploadedImage

        } catch let error as ImageUploadError {
            throw error

        } catch {
            throw ImageUploadError.invalidResponse
        }
    }


    @MainActor
    func delete(image: ManagedImage) async throws {
        var request = URLRequest(url: apiBaseURL.appendingPathComponent("v2/images/delete"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(try ImagePrivacySettings.ownerToken(), forHTTPHeaderField: "X-Lumaunt-Owner")
        request.httpBody = try JSONEncoder().encode(["key": image.key])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ImageUploadError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw ImageUploadError.serverError((try? JSONDecoder().decode(ServerErrorResponse.self, from: data).error) ?? "The image server could not delete this image.")
        }
    }

    // MARK: - Server Error Response

    private struct ServerErrorResponse: Codable {
        let error: String
    }
}
