import Foundation

struct UploadedImage: Codable, Equatable {
    let id: String
    let key: String
    let url: URL
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
        string: "https://lumaunt-api.liam-e92.workers.dev"
    )!

    private let maximumFileSize = 5 * 1024 * 1024


    // MARK: - Upload

    func upload(
        fileURL: URL
    ) async throws -> UploadedImage {

        guard fileURL.isFileURL else {
            throw ImageUploadError.invalidFile
        }

        // Check whether these exact image bytes
        // have already been uploaded.
        if let cachedImage = try uploadCache.uploadedImage(
            for: fileURL
        ) {
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

        let data: Data

        do {
            data = try Data(
                contentsOf: fileURL
            )
        } catch {
            throw ImageUploadError.invalidFile
        }

        guard !data.isEmpty else {
            throw ImageUploadError.invalidFile
        }

        guard data.count <= maximumFileSize else {
            throw ImageUploadError.fileTooLarge
        }

        let contentType = try contentType(
            for: fileURL
        )

        let uploadURL = apiBaseURL
            .appendingPathComponent("images")
            .appendingPathComponent("upload")

        var request = URLRequest(
            url: uploadURL
        )

        request.httpMethod = "POST"

        request.setValue(
            contentType,
            forHTTPHeaderField: "Content-Type"
        )

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


    // MARK: - Content Type

    private func contentType(
        for url: URL
    ) throws -> String {

        switch url.pathExtension.lowercased() {

        case "png":
            return "image/png"

        case "jpg", "jpeg":
            return "image/jpeg"

        case "webp":
            return "image/webp"

        default:
            throw ImageUploadError.unsupportedImageType
        }
    }
}


// MARK: - Server Error Response

private struct ServerErrorResponse: Codable {
    let error: String
}
