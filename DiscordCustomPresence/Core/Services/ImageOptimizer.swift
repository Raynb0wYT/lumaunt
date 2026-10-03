import Foundation
import ImageIO
import UniformTypeIdentifiers

struct OptimizedImage {
    let data: Data
    let contentType: String
    let fileExtension: String
}

enum ImageOptimizationError: LocalizedError {
    case unableToReadImage
    case unableToCreateImage
    case unableToCreateDestination

    var errorDescription: String? {
        switch self {
        case .unableToReadImage:
            return "Lumaunt could not read the image."

        case .unableToCreateImage:
            return "Lumaunt could not process the image."

        case .unableToCreateDestination:
            return "Lumaunt could not create the optimized image."
        }
    }
}

struct ImageOptimizer {

    static let maximumDimension = 1024

    static func optimize(
        fileURL: URL
    ) throws -> OptimizedImage {

        guard let source = CGImageSourceCreateWithURL(
            fileURL as CFURL,
            nil
        ) else {
            throw ImageOptimizationError.unableToReadImage
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumDimension
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            throw ImageOptimizationError.unableToCreateImage
        }

        let preserveTransparency = imageHasAlpha(image)

        let outputType: UTType
        let contentType: String
        let fileExtension: String
        let properties: [CFString: Any]

        if preserveTransparency {
            outputType = .png
            contentType = "image/png"
            fileExtension = "png"
            properties = [:]
        } else {
            outputType = .jpeg
            contentType = "image/jpeg"
            fileExtension = "jpg"

            properties = [
                kCGImageDestinationLossyCompressionQuality: 0.85
            ]
        }

        let output = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            output,
            outputType.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageOptimizationError.unableToCreateDestination
        }

        CGImageDestinationAddImage(
            destination,
            image,
            properties as CFDictionary
        )

        guard CGImageDestinationFinalize(destination) else {
            throw ImageOptimizationError.unableToCreateDestination
        }

        let data = output as Data

        print(
            "Image optimized:",
            "\(image.width)×\(image.height)",
            ByteCountFormatter.string(
                fromByteCount: Int64(data.count),
                countStyle: .file
            ),
            preserveTransparency
                ? "(PNG transparency preserved)"
                : "(JPEG)"
        )

        return OptimizedImage(
            data: data,
            contentType: contentType,
            fileExtension: fileExtension
        )
    }

    private static func imageHasAlpha(
        _ image: CGImage
    ) -> Bool {

        switch image.alphaInfo {
        case .first,
             .last,
             .premultipliedFirst,
             .premultipliedLast:
            return true

        case .none,
             .noneSkipFirst,
             .noneSkipLast,
             .alphaOnly:
            return false

        @unknown default:
            return false
        }
    }
}
