import Foundation


// MARK: - Moderation Policy

struct ModerationPolicy {

    static let shared =
        ModerationPolicy()


    // MARK: - Decision

    func evaluate(
        suspectedCategory:
            ContentFilter.ContentCategory,

        contextResult:
            ContextModerationResult
    ) -> ModerationPolicyDecision {

        // The server must return the same
        // category that Layer 1 asked it
        // to review.

        guard
            contextResult.category ==
                apiCategory(
                    for:
                        suspectedCategory
                )
        else {
            return .invalidResponse
        }


        // The service already validates
        // that:
        //
        // violation  == confirmed true
        // contextual == confirmed false
        //
        // Keep this switch explicit so the
        // policy remains easy to audit.

        switch contextResult.classification {

        case .violation:

            guard
                contextResult.confirmed
            else {
                return .invalidResponse
            }


            return .blocked(
                categories: [
                    suspectedCategory,
                ]
            )


        case .contextual:

            guard
                !contextResult.confirmed
            else {
                return .invalidResponse
            }


            return .allowed
        }
    }


    // MARK: - API Category

    func apiCategory(
        for category:
            ContentFilter.ContentCategory
    ) -> String {

        switch category {

        case .hatefulConduct:

            return "hatefulConduct"


        case .threats:

            return "threats"


        case .harassment:

            return "harassment"


        case .sexualContent:

            return "sexualContent"


        case .childSafety:

            return "childSafety"


        case .violentExtremism:

            return "violentExtremism"
        }
    }
}


// MARK: - Policy Decision

enum ModerationPolicyDecision:
    Equatable
{

    case allowed

    case blocked(
        categories:
            Set<
                ContentFilter.ContentCategory
            >
    )

    case invalidResponse
}
