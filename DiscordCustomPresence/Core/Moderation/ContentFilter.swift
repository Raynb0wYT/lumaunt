import Foundation

struct ContentFilter {

    enum ValidationResult: Equatable {
        case allowed
        case blocked(reason: String)
    }

    static func validate(_ text: String) -> ValidationResult {
        let cleaned = normalize(text)

        guard !cleaned.isEmpty else {
            return .allowed
        }

        // Filtering rules will be added here.

        return .allowed
    }

    private static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
