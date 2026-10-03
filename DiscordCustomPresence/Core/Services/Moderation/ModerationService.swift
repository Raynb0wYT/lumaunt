import Foundation


// MARK: - Moderation Service

struct ModerationService {

    static let shared = ModerationService()

    private let baseURL = URL(
        string: "https://api.lumaunt.app"
    )!

    private let session: URLSession


    // MARK: - Initialization

    init(
        session: URLSession = .shared
    ) {
        self.session = session
    }


    // MARK: - Moderate Text

    func moderate(
        text: String
    ) async throws -> ModerationResult {

        let trimmedText =
            try validatedText(
                text
            )


        let endpoint =
            baseURL.appendingPathComponent(
                "v1/moderate/text"
            )


        let requestBody =
            ModerationRequest(
                text: trimmedText
            )


        let data =
            try await performRequest(
                endpoint: endpoint,
                body: requestBody
            )


        let apiResponse:
            ModerationAPIResponse

        do {
            apiResponse =
                try JSONDecoder().decode(
                    ModerationAPIResponse.self,
                    from: data
                )
        } catch {
            throw ModerationServiceError
                .invalidResponse
        }


        guard apiResponse.success else {
            throw ModerationServiceError
                .invalidResponse
        }


        return ModerationResult(
            allowed:
                apiResponse.allowed,

            flagged:
                apiResponse.flagged,

            categories:
                Set(
                    apiResponse.categories
                ),

            scores:
                apiResponse.scores
        )
    }


    // MARK: - Moderate Context

    func moderateContext(
        text: String,
        suspectedCategory: String
    ) async throws -> ContextModerationResult {

        let trimmedText =
            try validatedText(
                text
            )


        let trimmedCategory =
            suspectedCategory
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )


        guard !trimmedCategory.isEmpty else {
            throw ModerationServiceError
                .invalidCategory
        }


        let endpoint =
            baseURL.appendingPathComponent(
                "v1/moderate/context"
            )


        let requestBody =
            ContextModerationRequest(
                text: trimmedText,
                suspectedCategory:
                    trimmedCategory
            )


        let data =
            try await performRequest(
                endpoint: endpoint,
                body: requestBody
            )


        let apiResponse:
            ContextModerationAPIResponse

        do {
            apiResponse =
                try JSONDecoder().decode(
                    ContextModerationAPIResponse.self,
                    from: data
                )
        } catch {
            throw ModerationServiceError
                .invalidResponse
        }


        guard apiResponse.success else {
            throw ModerationServiceError
                .invalidResponse
        }


        guard
            apiResponse.category ==
                trimmedCategory
        else {
            throw ModerationServiceError
                .invalidResponse
        }


        let classification:
            ContextModerationClassification

        switch apiResponse.classification {

        case "violation":
            classification =
                .violation

        case "contextual":
            classification =
                .contextual

        default:
            throw ModerationServiceError
                .invalidResponse
        }


        guard
            apiResponse.confirmed ==
                (
                    classification ==
                        .violation
                )
        else {
            throw ModerationServiceError
                .invalidResponse
        }


        return ContextModerationResult(
            confirmed:
                apiResponse.confirmed,

            category:
                apiResponse.category,

            classification:
                classification
        )
    }


    // MARK: - Validate Text

    private func validatedText(
        _ text: String
    ) throws -> String {

        let trimmedText =
            text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )


        guard !trimmedText.isEmpty else {
            throw ModerationServiceError
                .emptyText
        }


        return trimmedText
    }


    // MARK: - Perform Request

    private func performRequest<Body: Encodable>(
        endpoint: URL,
        body: Body
    ) async throws -> Data {

        var request =
            URLRequest(
                url: endpoint
            )


        request.httpMethod =
            "POST"


        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Content-Type"
        )


        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Accept"
        )


        request.timeoutInterval =
            15


        do {
            request.httpBody =
                try JSONEncoder().encode(
                    body
                )
        } catch {
            throw ModerationServiceError
                .requestEncodingFailed
        }


        let data: Data
        let response: URLResponse


        do {
            (
                data,
                response
            ) =
                try await session.data(
                    for: request
                )
        } catch let error as URLError {

            if error.code == .timedOut {
                throw ModerationServiceError
                    .timedOut
            }


            throw ModerationServiceError
                .networkUnavailable

        } catch {
            throw ModerationServiceError
                .networkUnavailable
        }


        guard
            let httpResponse =
                response as? HTTPURLResponse
        else {
            throw ModerationServiceError
                .invalidResponse
        }


        guard
            (200...299).contains(
                httpResponse.statusCode
            )
        else {

            if
                let apiError =
                    try? JSONDecoder().decode(
                        ModerationAPIErrorResponse.self,
                        from: data
                    )
            {
                throw ModerationServiceError
                    .serverError(
                        message:
                            apiError.error
                    )
            }


            throw ModerationServiceError
                .serverError(
                    message:
                        "The moderation service returned an error."
                )
        }


        return data
    }
}


// MARK: - Moderation Result

struct ModerationResult: Equatable {

    let allowed: Bool

    let flagged: Bool

    let categories: Set<String>

    let scores: [String: Double]


    // MARK: Category Helpers

    func containsCategory(
        _ category: String
    ) -> Bool {

        categories.contains(
            category
        )
    }


    func containsAnyCategory(
        _ categoriesToCheck: Set<String>
    ) -> Bool {

        !categories.isDisjoint(
            with: categoriesToCheck
        )
    }


    func score(
        for category: String
    ) -> Double? {

        scores[
            category
        ]
    }
}


// MARK: - Context Moderation Result

struct ContextModerationResult:
    Equatable
{

    let confirmed: Bool

    let category: String

    let classification:
        ContextModerationClassification
}


// MARK: - Context Classification

enum ContextModerationClassification:
    String,
    Equatable
{

    case violation

    case contextual
}


// MARK: - Moderation Request

private struct ModerationRequest:
    Encodable
{

    let text: String
}


// MARK: - Context Moderation Request

private struct ContextModerationRequest:
    Encodable
{

    let text: String

    let suspectedCategory: String
}


// MARK: - Moderation API Response

private struct ModerationAPIResponse:
    Decodable
{

    let success: Bool

    let allowed: Bool

    let flagged: Bool

    let categories: [String]

    let scores: [String: Double]
}


// MARK: - Context Moderation API Response

private struct ContextModerationAPIResponse:
    Decodable
{

    let success: Bool

    let confirmed: Bool

    let category: String

    let classification: String
}


// MARK: - API Error Response

private struct ModerationAPIErrorResponse:
    Decodable
{

    let error: String
}


// MARK: - Errors

enum ModerationServiceError:
    LocalizedError
{

    case emptyText

    case invalidCategory

    case requestEncodingFailed

    case networkUnavailable

    case timedOut

    case invalidResponse

    case serverError(
        message: String
    )


    var errorDescription: String? {

        switch self {

        case .emptyText:

            return "There is no text to review."


        case .invalidCategory:

            return "Lumaunt could not determine which content category to review."


        case .requestEncodingFailed:

            return "Lumaunt could not prepare the moderation request."


        case .networkUnavailable:

            return "Lumaunt could not reach the moderation service. Check your internet connection and try again."


        case .timedOut:

            return "The moderation check took too long. Please try again."


        case .invalidResponse:

            return "Lumaunt received an invalid response from the moderation service."


        case .serverError(
            let message
        ):

            return message
        }
    }
}
