import XCTest
@testable import Lumaunt

final class ContentFilterTests: XCTestCase {

    // MARK: - Helpers

    private func assertAllowed(
        _ text: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let result = ContentFilter.validate(text)

        XCTAssertEqual(
            result,
            .allowed,
            """
            Expected content to be allowed:
            "\(text)"

            Received:
            \(result)
            """,
            file: file,
            line: line
        )
    }


    private func assertNeedsReview(
        _ text: String,
        category: ContentFilter.ContentCategory,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let result = ContentFilter.validate(text)

        switch result {

        case .needsReview(let categories):

            XCTAssertTrue(
                categories.contains(category),
                """
                Expected review category \(category) for:
                "\(text)"

                Received categories:
                \(categories)
                """,
                file: file,
                line: line
            )


        case .allowed:

            XCTFail(
                """
                Expected content to require review:
                "\(text)"

                Received:
                allowed
                """,
                file: file,
                line: line
            )


        case .blocked(
            let blockedCategory,
            let reason
        ):

            XCTFail(
                """
                Expected content to require review, not be locally blocked:
                "\(text)"

                Blocked category:
                \(blockedCategory)

                Reason:
                \(reason)
                """,
                file: file,
                line: line
            )
        }
    }


    private func assertBlocked(
        _ text: String,
        category: ContentFilter.ContentCategory,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let result = ContentFilter.validate(text)

        switch result {

        case .blocked(
            let blockedCategory,
            _
        ):

            XCTAssertEqual(
                blockedCategory,
                category,
                """
                Expected blocked category \(category) for:
                "\(text)"

                Received:
                \(blockedCategory)
                """,
                file: file,
                line: line
            )


        case .allowed:

            XCTFail(
                """
                Expected content to be blocked:
                "\(text)"

                Received:
                allowed
                """,
                file: file,
                line: line
            )


        case .needsReview(let categories):

            XCTFail(
                """
                Expected content to be locally blocked:
                "\(text)"

                Received review categories:
                \(categories)
                """,
                file: file,
                line: line
            )
        }
    }


    // MARK: - Ordinary Content

    func testOrdinaryContentIsAllowed() {

        assertAllowed(
            "Playing Valorant"
        )

        assertAllowed(
            "Ranked with friends"
        )

        assertAllowed(
            "this fucking game sucks"
        )

        assertAllowed(
            "damn that was close"
        )

        assertAllowed(
            "what the hell was that"
        )
    }


    // MARK: - Gaming Violence

    func testGamingViolenceIsAllowed() {

        assertAllowed(
            "kill the boss"
        )

        assertAllowed(
            "shoot the enemy"
        )

        assertAllowed(
            "I got killed"
        )

        assertAllowed(
            "you killed me"
        )

        assertAllowed(
            "you murdered me that round"
        )

        assertAllowed(
            "I'm going to attack the objective"
        )

        assertAllowed(
            "deathmatch is fun"
        )

        assertAllowed(
            "I'll kill the boss before you arrive"
        )

        assertAllowed(
            "I'll shoot the enemy before you arrive"
        )

        assertAllowed(
            "I'll attack the objective while you defend"
        )

        assertAllowed(
            "I'll hurt the boss before you get here"
        )
    }


    // MARK: - Direct Threat Review

    func testDirectThreatsNeedReview() {

        assertNeedsReview(
            "I'll kill you",
            category: .threats
        )

        assertNeedsReview(
            "I will kill you",
            category: .threats
        )

        assertNeedsReview(
            "I'm going to kill you",
            category: .threats
        )

        assertNeedsReview(
            "I'll shoot you",
            category: .threats
        )

        assertNeedsReview(
            "I am going to stab you",
            category: .threats
        )

        assertNeedsReview(
            "I will hurt you",
            category: .threats
        )

        assertNeedsReview(
            "I'll murder you",
            category: .threats
        )
    }


    // MARK: - Third-Person Threat Review

    func testThirdPersonThreatsNeedReview() {

        assertNeedsReview(
            "I'll kill him",
            category: .threats
        )

        assertNeedsReview(
            "I will shoot her",
            category: .threats
        )

        assertNeedsReview(
            "I'm going to stab somebody",
            category: .threats
        )

        assertNeedsReview(
            "I will hurt someone",
            category: .threats
        )
    }


    // MARK: - Normalization

    func testThreatReviewIgnoresCapitalization() {

        assertNeedsReview(
            "I WILL KILL YOU",
            category: .threats
        )

        assertNeedsReview(
            "I Will Shoot You",
            category: .threats
        )
    }


    func testThreatReviewHandlesPunctuation() {

        assertNeedsReview(
            "I'll kill... you!",
            category: .threats
        )

        assertNeedsReview(
            "I will shoot, you.",
            category: .threats
        )
    }


    // MARK: - False Positive Protection

    func testThreatWordsWithoutTargetsAreAllowed() {

        assertAllowed(
            "kill"
        )

        assertAllowed(
            "shoot"
        )

        assertAllowed(
            "stab"
        )

        assertAllowed(
            "attack"
        )

        assertAllowed(
            "murder mystery"
        )
    }


    func testTargetsWithoutThreatsAreAllowed() {

        assertAllowed(
            "you are awesome"
        )

        assertAllowed(
            "playing with her"
        )

        assertAllowed(
            "waiting for him"
        )

        assertAllowed(
            "someone joined"
        )
    }


    // MARK: - Local Blocking

    /*
     We intentionally have no high-confidence local
     blocking rules yet.

     Once we add one, this section should test that
     the content goes directly to .blocked rather than
     .needsReview.

     Keep assertBlocked() above so the test suite is
     already prepared for that.
    */
}
