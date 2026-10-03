import Foundation
import ImageIO

enum ImageValidationError: LocalizedError {
    case unableToReadImage
    case dimensionsTooLarge(
        width: Int,
        height: Int,
        maximum: Int
    )

    var errorDescription: String? {
        switch self {
        case .unableToReadImage:
            return "Lumaunt could not read the image."

        case .dimensionsTooLarge(
            let width,
            let height,
            let maximum
        ):
            return """
            Image dimensions are \(width)×\(height). \
            Images must be no larger than \(maximum)×\(maximum).
            """
        }
    }
}

struct ImageValidator {

    static let maximumDimension = 4096

    static func validateDimensions(
        of fileURL: URL
    ) throws {

        guard let source = CGImageSourceCreateWithURL(
            fileURL as CFURL,
            nil
        ) else {
            throw ImageValidationError.unableToReadImage
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(
            source,
            0,
            nil
        ) as? [CFString: Any],
        let width = properties[kCGImagePropertyPixelWidth] as? Int,
        let height = properties[kCGImagePropertyPixelHeight] as? Int
        else {
            throw ImageValidationError.unableToReadImage
        }

        guard width <= maximumDimension,
              height <= maximumDimension
        else {
            throw ImageValidationError.dimensionsTooLarge(
                width: width,
                height: height,
                maximum: maximumDimension
            )
        }

        print(
            "Image dimensions validated:",
            "\(width)×\(height)"
        )
    }
}
