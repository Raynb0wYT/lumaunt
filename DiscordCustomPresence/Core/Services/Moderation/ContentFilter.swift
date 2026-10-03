import Foundation

struct ContentFilter {

    // MARK: - Content Category

    enum ContentCategory:
        String,
        Equatable,
        Hashable,
        CaseIterable
    {
        case hatefulConduct
        case threats
        case harassment
        case sexualContent
        case childSafety
        case violentExtremism

        var displayName: String {
            switch self {
            case .hatefulConduct:
                return "Hateful Conduct"

            case .threats:
                return "Threats"

            case .harassment:
                return "Harassment"

            case .sexualContent:
                return "Sexual Content"

            case .childSafety:
                return "Child Safety"

            case .violentExtremism:
                return "Violent Extremism"
            }
        }
    }


    // MARK: - Validation Result

    enum ValidationResult: Equatable {

        /// Local filtering found nothing concerning.
        ///
        /// The content can continue without requiring
        /// remote moderation.
        case allowed


        /// Local filtering found something potentially
        /// policy-sensitive, but not enough context to
        /// confidently block it.
        ///
        /// Layer 2 should review this content.
        case needsReview(
            categories: Set<ContentCategory>
        )


        /// Local filtering found a high-confidence
        /// violation.
        case blocked(
            category: ContentCategory,
            reason: String
        )
    }


    // MARK: - Rule Decision

    private enum RuleDecision {

        /// A high-confidence match should immediately
        /// block the content.
        case block


        /// A context-sensitive match should be sent to
        /// Layer 2 for additional review.
        case review
    }


    // MARK: - Matching Style

    private enum MatchingStyle {

        /// Matches complete normalized words or phrases.
        case wholeTerm

        /// Matches against the separator-free form.
        ///
        /// Use this very carefully because it is more
        /// aggressive and can produce false positives.
        case compactTerm

        /// Matches using aggressive normalization intended
        /// specifically for high-confidence filter-evasion
        /// detection.
        case obfuscatedTerm
    }


    // MARK: - Context Relationship

    private enum ContextRelationship {

        /// Every required group must appear somewhere
        /// in the same field.
        case anywhere


        /// Required groups must appear within a certain
        /// token distance.
        ///
        /// Direction does not matter.
        case withinTokens(Int)


        /// Required groups must appear in their declared
        /// order and within a certain token distance.
        case orderedWithinTokens(Int)
    }


    // MARK: - Simple Rule

    private struct Rule {

        let category: ContentCategory

        let terms: [String]

        let reason: String

        let matching: MatchingStyle

        let decision: RuleDecision


        init(
            category: ContentCategory,
            terms: [String],
            reason: String,
            matching: MatchingStyle = .wholeTerm,
            decision: RuleDecision = .block
        ) {
            self.category = category
            self.terms = terms
            self.reason = reason
            self.matching = matching
            self.decision = decision
        }
    }


    // MARK: - Contextual Rule

    private struct ContextualRule {

        let category: ContentCategory

        let requiredGroups: [[String]]

        let reason: String

        let matching: MatchingStyle

        let relationship: ContextRelationship

        let decision: RuleDecision


        init(
            category: ContentCategory,
            requiredGroups: [[String]],
            reason: String,
            matching: MatchingStyle = .wholeTerm,
            relationship: ContextRelationship = .anywhere,
            decision: RuleDecision = .review
        ) {
            self.category = category
            self.requiredGroups = requiredGroups
            self.reason = reason
            self.matching = matching
            self.relationship = relationship
            self.decision = decision
        }
    }


    // MARK: - Normalized Content

    private struct NormalizedContent {

        /// Human-readable normalized representation.
        let words: String


        /// Separator-free representation.
        let compact: String


        /// Individual normalized words.
        let tokens: [String]

        /// Original unmodified input for specialized
        /// anti-evasion matching.
        let original: String
    }


    // MARK: - Token Match

    private struct TokenMatch {

        let start: Int

        let end: Int
    }


    // MARK: - High-Confidence Rules

    /*
     These rules should ONLY contain content where
     Lumaunt can make a high-confidence local decision.

     Do not use this as a generic profanity list.

     Ordinary profanity is intentionally allowed.

     Rules that require understanding context should
     normally use:

         decision: .review

     instead.
    */

    private static let rules: [Rule] = [

        // MARK: - Racial / Ethnic Slurs

        /*
         Explicit racial and ethnic slurs are treated as
         high-confidence violations.

         Unlike contextual hateful-conduct rules, these
         are blocked locally and are not sent to Layer 2.

         Keep matching conservative to avoid substring
         false positives.
        */

        Rule(
            category: .hatefulConduct,

            terms: [
                // Anti-Black
                "nigger",
                "niggers",
                "nigga",
                "niggas",
                "coon",
                "coons",
                "sambo",

                // Anti-Asian
                "chink",
                "chinks",
                "gook",
                "gooks",

                // Anti-Hispanic / Latino
                "spic",
                "spics",
                "wetback",
                "wetbacks",

                // Anti-Arab / Middle Eastern
                "sand nigger",
                "sand niggers",
                "towelhead",
                "towelheads",

                // Anti-Jewish
                "kike",
                "kikes"
            ],

            reason:
                "Racial or ethnic slurs are not allowed.",

            matching:
                .obfuscatedTerm,

            decision:
                .block
        )
    ]


    // MARK: - Contextual Rules

    private static let contextualRules:
        [ContextualRule] = [

        // MARK: Direct Threats

        /*
         Direct action -> second-person target.

         Because violent language is extremely common
         in gaming, these are marked for review rather
         than automatically blocked.

         Examples:

         "I'll kill you"
             -> needsReview(.threats)

         "kill the boss"
             -> allowed
        */

        ContextualRule(
            category: .threats,

            requiredGroups: [
                [
                    "kill",
                    "murder",
                    "shoot",
                    "stab",
                    "hurt",
                    "attack"
                ],

                [
                    "you",
                    "yourself"
                ]
            ],

            reason:
                "This presence may contain a direct " +
                "threat against another person.",

            relationship:
                .orderedWithinTokens(0),

            decision:
                .review
        ),


        // MARK: Third-Person Threats

        ContextualRule(
            category: .threats,

            requiredGroups: [
                [
                    "kill",
                    "murder",
                    "shoot",
                    "stab",
                    "hurt",
                    "attack"
                ],

                [
                    "him",
                    "her",
                    "someone",
                    "somebody"
                ]
            ],

            reason:
                "This presence may contain a threat " +
                "against another person.",

            relationship:
                .orderedWithinTokens(0),

            decision:
                .review
        ),

        ContextualRule(
            category: .threats,

            requiredGroups: [
                [
                    "kill",
                    "murder",
                    "shoot",
                    "stab",
                    "hurt",
                    "attack"
                ],

                [
                    "him",
                    "her",
                    "someone",
                    "somebody"
                ]
            ],

            reason:
                "This presence may contain a threat " +
                "against another person.",

            relationship:
                .orderedWithinTokens(0),

            decision:
                .review
        ),


        // MARK: Hateful Conduct

        /*
         Potentially hateful or degrading language
         combined with a protected-class reference.

         Layer 1 does not decide whether the statement
         is actually hateful conduct.

         Quotation, reporting, discussion, reclaimed
         language, and other contextual uses must be
         decided by Layer 2.
        */

        // MARK: Hateful Conduct - Hostility / Degradation

        ContextualRule(
            category: .hatefulConduct,

            requiredGroups: [
                [
                    "hate",
                    "hates",
                    "hated",
                    "disgusting",
                    "inferior",
                    "subhuman",
                    "vermin"
                ],

                [
                    // Race / ethnicity
                    "black people",
                    "white people",
                    "asian people",
                    "latino people",
                    "latina people",
                    "hispanic people",

                    // Religion
                    "christians",
                    "muslims",
                    "jews",
                    "jewish people",
                    "hindus",
                    "buddhists",

                    // Sex / gender
                    "men",
                    "women",
                    "trans people",
                    "transgender people",

                    // Sexual orientation
                    "gay people",
                    "lesbians",
                    "bisexual people",

                    // Disability
                    "disabled people",

                    // Nationality
                    "americans",
                    "canadians",
                    "mexicans"
                ]
            ],

            reason:
                "This presence may contain hateful or " +
                "degrading conduct targeting a protected class.",

            relationship:
                .anywhere,

            decision:
                .review
        ),


        // MARK: Hateful Conduct - Exclusion

        ContextualRule(
            category: .hatefulConduct,

            requiredGroups: [
                [
                    "ban",
                    "exclude",
                    "remove",
                    "deport",
                    "expel"
                ],

                [
                    "black people",
                    "white people",
                    "asian people",
                    "latino people",
                    "latina people",
                    "hispanic people",

                    "christians",
                    "muslims",
                    "jews",
                    "jewish people",
                    "hindus",
                    "buddhists",

                    "men",
                    "women",
                    "trans people",
                    "transgender people",

                    "gay people",
                    "lesbians",
                    "bisexual people",

                    "disabled people"
                ]
            ],

            reason:
                "This presence may advocate exclusion of " +
                "people based on a protected characteristic.",

            relationship:
                .withinTokens(5),

            decision:
                .review
        ),


        // MARK: Hateful Conduct - Supremacy

        ContextualRule(
            category: .hatefulConduct,

            requiredGroups: [
                [
                    "superior",
                    "better",
                    "inferior",
                    "lesser"
                ],

                [
                    "race",
                    "races",
                    "ethnicity",
                    "ethnicities"
                ]
            ],

            reason:
                "This presence may express racial or ethnic " +
                "supremacy or inferiority.",

            relationship:
                .withinTokens(5),

            decision:
                .review
        ),

        // MARK: Hateful Conduct - Targeted Violence

        ContextualRule(
            category: .hatefulConduct,

            requiredGroups: [
                [
                    "kill",
                    "kills",
                    "killed",
                    "killing",
                    "murder",
                    "murders",
                    "murdered",
                    "murdering",
                    "shoot",
                    "shoots",
                    "shot",
                    "shooting",
                    "stab",
                    "stabs",
                    "stabbed",
                    "stabbing",
                    "attack",
                    "attacks",
                    "attacked",
                    "attacking",
                    "hurt",
                    "hurting"
                ],

                [
                    "black people",
                    "white people",
                    "asian people",
                    "latino people",
                    "latina people",
                    "hispanic people",

                    "christians",
                    "muslims",
                    "jews",
                    "jewish people",
                    "hindus",
                    "buddhists",

                    "men",
                    "women",
                    "trans people",
                    "transgender people",

                    "gay people",
                    "lesbians",
                    "bisexual people",

                    "disabled people"
                ]
            ],

            reason:
                "This presence may contain violence " +
                "targeting a protected class.",

            relationship:
                .withinTokens(5),

            decision:
                .review
        ),

        // MARK: Harassment

        /*
         Targeted abusive or degrading language.

         Layer 1 only identifies potentially targeted
         abuse. Layer 2 determines whether the content
         is actually harassment or is quotation,
         discussion, joking, fictional dialogue, etc.
        */

        ContextualRule(
            category: .harassment,

            requiredGroups: [
                [
                    "worthless",
                    "pathetic",
                    "disgusting",
                    "repulsive",
                    "useless",
                    "loser",
                    "failure",
                    "idiot",
                    "moron"
                ],

                [
                    "you",
                    "your",
                    "youre",
                    "he",
                    "him",
                    "his",
                    "she",
                    "her",
                    "they",
                    "them",
                    "person",
                    "people",
                    "someone",
                    "somebody"
                ]
            ],

            reason:
                "This presence may contain targeted " +
                "abusive or degrading language.",

            relationship:
                .withinTokens(3),

            decision:
                .review
        ),


        // MARK: Sexual Content

        /*
         Potentially explicit sexual language.

         These terms are sent to Layer 2 rather than
         blocked locally because legitimate discussion,
         jokes, quotations, health-related discussion,
         and other contextual uses may be non-violating.
        */

        ContextualRule(
            category: .sexualContent,

            requiredGroups: [
                [
                    "sex",
                    "sexual",
                    "nude",
                    "nudes",
                    "naked",
                    "porn",
                    "pornography",
                    "intercourse"
                ]
            ],

            reason:
                "This presence may contain sexually " +
                "explicit content.",

            relationship:
                .anywhere,

            decision:
                .review
        ),


        // MARK: Child Safety

        /*
         Sexual language combined with references to
         minors receives separate child-safety review.

         Layer 1 does not determine intent or meaning.
         Layer 2 must evaluate the complete context.
        */

        ContextualRule(
            category: .childSafety,

            requiredGroups: [
                [
                    "sex",
                    "sexual",
                    "nude",
                    "nudes",
                    "naked",
                    "porn",
                    "pornography",
                    "explicit"
                ],

                [
                    "child",
                    "children",
                    "kid",
                    "kids",
                    "minor",
                    "minors",
                    "underage",
                    "teen",
                    "teenager"
                ]
            ],

            reason:
                "This presence may contain sexual " +
                "content involving a minor.",

            relationship:
                .withinTokens(5),

            decision:
                .review
        ),


        // MARK: Violent Extremism

        /*
         Potential praise, support, or promotion of
         extremist violence.

         Organization names alone are intentionally
         insufficient. Discussion, news, history,
         criticism, and condemnation must remain
         distinguishable by Layer 2.
        */

        ContextualRule(
            category: .violentExtremism,

            requiredGroups: [
                [
                    "support",
                    "supports",
                    "supporting",
                    "praise",
                    "praises",
                    "glorify",
                    "glorifies",
                    "glorifying",
                    "join",
                    "joining"
                ],

                [
                    "terrorist",
                    "terrorists",
                    "terrorism",
                    "extremist",
                    "extremists",
                    "extremism"
                ]
            ],

            reason:
                "This presence may contain support " +
                "for violent extremist activity.",

            relationship:
                .withinTokens(5),

            decision:
                .review
        )
    ]


    // MARK: - Public Validation

    static func validate(
        _ text: String
    ) -> ValidationResult {

        let normalized =
            normalize(text)


        guard
            !normalized.words.isEmpty
        else {
            return .allowed
        }


        var reviewCategories:
            Set<ContentCategory> = []


        // MARK: Simple Rules

        for rule in rules {

            guard
                matches(
                    rule,
                    in: normalized
                )
            else {
                continue
            }


            switch rule.decision {

            case .block:

                return .blocked(
                    category:
                        rule.category,
                    reason:
                        rule.reason
                )


            case .review:

                reviewCategories.insert(
                    rule.category
                )
            }
        }


        // MARK: Contextual Rules

        for rule in contextualRules {

            guard
                matches(
                    rule,
                    in: normalized
                )
            else {
                continue
            }


            switch rule.decision {

            case .block:

                return .blocked(
                    category:
                        rule.category,
                    reason:
                        rule.reason
                )


            case .review:

                reviewCategories.insert(
                    rule.category
                )
            }
        }


        // If one or more local rules found potentially
        // sensitive content, Layer 2 should review it.

        if !reviewCategories.isEmpty {

            return .needsReview(
                categories:
                    reviewCategories
            )
        }


        return .allowed
    }


    // MARK: - Simple Rule Matching

    private static func matches(
        _ rule: Rule,
        in content: NormalizedContent
    ) -> Bool {

        containsAny(
            rule.terms,
            in: content,
            matching:
                rule.matching
        )
    }


    // MARK: - Contextual Rule Matching

    private static func matches(
        _ rule: ContextualRule,
        in content: NormalizedContent
    ) -> Bool {

        guard
            !rule.requiredGroups.isEmpty
        else {
            return false
        }


        switch rule.relationship {

        case .anywhere:

            for group in
                rule.requiredGroups {

                guard
                    !group.isEmpty
                else {
                    return false
                }


                if !containsAny(
                    group,
                    in: content,
                    matching:
                        rule.matching
                ) {
                    return false
                }
            }


            return true


        case .withinTokens(
            let distance
        ):

            return matchesWithProximity(
                groups:
                    rule.requiredGroups,
                content:
                    content,
                maximumDistance:
                    distance,
                ordered:
                    false
            )


        case .orderedWithinTokens(
            let distance
        ):

            return matchesWithProximity(
                groups:
                    rule.requiredGroups,
                content:
                    content,
                maximumDistance:
                    distance,
                ordered:
                    true
            )
        }
    }


    // MARK: - Proximity Matching

    private static func matchesWithProximity(
        groups: [[String]],
        content: NormalizedContent,
        maximumDistance: Int,
        ordered: Bool
    ) -> Bool {

        guard
            !groups.isEmpty,
            maximumDistance >= 0
        else {
            return false
        }


        let matchGroups =
            groups.map {
                tokenMatches(
                    for: $0,
                    in: content.tokens
                )
            }


        guard
            matchGroups.allSatisfy({
                !$0.isEmpty
            })
        else {
            return false
        }


        guard
            let firstMatches =
                matchGroups.first
        else {
            return false
        }


        for firstMatch in firstMatches {

            if canBuildMatchChain(
                groupIndex: 1,
                previousMatch:
                    firstMatch,
                matchGroups:
                    matchGroups,
                maximumDistance:
                    maximumDistance,
                ordered:
                    ordered
            ) {
                return true
            }
        }


        return false
    }


    private static func canBuildMatchChain(
        groupIndex: Int,
        previousMatch: TokenMatch,
        matchGroups: [[TokenMatch]],
        maximumDistance: Int,
        ordered: Bool
    ) -> Bool {

        if groupIndex >=
            matchGroups.count {

            return true
        }


        for candidate in
            matchGroups[groupIndex] {

            guard
                relationshipMatches(
                    previous:
                        previousMatch,
                    candidate:
                        candidate,
                    maximumDistance:
                        maximumDistance,
                    ordered:
                        ordered
                )
            else {
                continue
            }


            if canBuildMatchChain(
                groupIndex:
                    groupIndex + 1,
                previousMatch:
                    candidate,
                matchGroups:
                    matchGroups,
                maximumDistance:
                    maximumDistance,
                ordered:
                    ordered
            ) {
                return true
            }
        }


        return false
    }


    private static func relationshipMatches(
        previous: TokenMatch,
        candidate: TokenMatch,
        maximumDistance: Int,
        ordered: Bool
    ) -> Bool {

        if ordered {

            guard
                candidate.start >
                    previous.end
            else {
                return false
            }


            let gap =
                candidate.start -
                previous.end -
                1


            return gap <=
                maximumDistance
        }


        let gap: Int


        if candidate.start >
            previous.end {

            gap =
                candidate.start -
                previous.end -
                1

        } else if previous.start >
            candidate.end {

            gap =
                previous.start -
                candidate.end -
                1

        } else {

            gap = 0
        }


        return gap <=
            maximumDistance
    }


    // MARK: - Token Matching

    private static func tokenMatches(
        for terms: [String],
        in tokens: [String]
    ) -> [TokenMatch] {

        var matches:
            [TokenMatch] = []


        for term in terms {

            let normalizedTerm =
                normalize(term)


            let termTokens =
                normalizedTerm.tokens


            guard
                !termTokens.isEmpty,
                termTokens.count <=
                    tokens.count
            else {
                continue
            }


            let lastStart =
                tokens.count -
                termTokens.count


            for start in 0...lastStart {

                let end =
                    start +
                    termTokens.count -
                    1


                let candidate =
                    Array(
                        tokens[start...end]
                    )


                if candidate ==
                    termTokens {

                    matches.append(
                        TokenMatch(
                            start: start,
                            end: end
                        )
                    )
                }
            }
        }


        return matches
    }


    // MARK: - Term Collection Matching

    private static func containsAny(
        _ terms: [String],
        in content: NormalizedContent,
        matching: MatchingStyle
    ) -> Bool {

        for term in terms {

            let normalizedTerm =
                normalize(term)


            guard
                !normalizedTerm.words.isEmpty
            else {
                continue
            }


            switch matching {

            case .wholeTerm:

                if matchesWholeTerm(
                    normalizedTerm.words,
                    in: content.words
                ) {
                    return true
                }


            case .compactTerm:

                if matchesCompactTerm(
                    normalizedTerm.compact,
                    in: content.compact
                ) {
                    return true
                }

            case .obfuscatedTerm:

                if matchesObfuscatedTerm(
                    term,
                    in: content.original
                ) {
                    return true
                }
            }
        }


        return false
    }

    // MARK: - Obfuscated-Term Matching

    private static func matchesObfuscatedTerm(
        _ term: String,
        in content: String
    ) -> Bool {

        let normalizedTerm =
            normalizeObfuscated(
                term
            )

        guard
            !normalizedTerm.isEmpty,
            !content.isEmpty
        else {
            return false
        }

        let contentTokens =
            content.split(
                separator: " "
            )
            .map(
                String.init
            )

        // First check each individual token.
        //
        // This catches:
        // n1gger
        // N1GG3R
        // etc.
        for token in contentTokens {

            let normalizedToken =
                normalizeObfuscated(
                    token
                )

            if normalizedToken ==
                normalizedTerm {

                return true
            }
        }

        // Then allow a sequence of single-character
        // tokens to reconstruct an intentionally
        // separated word.
        //
        // This catches:
        // n i g g e r
        // n.i.g.g.e.r
        // n-i-g-g-e-r
        //
        // without compacting an entire normal sentence.

        guard
            normalizedTerm.count >= 4
        else {
            return false
        }

        let termCharacters =
            Array(
                normalizedTerm
            )

        guard
            contentTokens.count >=
                termCharacters.count
        else {
            return false
        }

        let lastStart =
            contentTokens.count -
            termCharacters.count

        for start in 0...lastStart {

            var reconstructed = ""
            var validSequence = true

            for offset in
                0..<termCharacters.count {

                let token =
                    contentTokens[
                        start + offset
                    ]

                let normalizedToken =
                    normalizeObfuscated(
                        token
                    )

                guard
                    normalizedToken.count == 1
                else {
                    validSequence = false
                    break
                }

                reconstructed +=
                    normalizedToken
            }

            if validSequence,
               reconstructed ==
                normalizedTerm {

                return true
            }
        }

        return false
    }

    // MARK: - Whole-Term Matching

    private static func matchesWholeTerm(
        _ term: String,
        in content: String
    ) -> Bool {

        guard
            !term.isEmpty,
            !content.isEmpty
        else {
            return false
        }


        if content == term {
            return true
        }


        let paddedContent =
            " \(content) "

        let paddedTerm =
            " \(term) "


        return paddedContent.contains(
            paddedTerm
        )
    }


    // MARK: - Compact Matching

    private static func matchesCompactTerm(
        _ term: String,
        in content: String
    ) -> Bool {

        guard
            !term.isEmpty,
            !content.isEmpty
        else {
            return false
        }


        return content.contains(
            term
        )
    }


    // MARK: - Normalization

    private static func normalize(
        _ text: String
    ) -> NormalizedContent {

        let unicodeNormalized =
            normalizeUnicode(
                text
            )


        let lowercase =
            unicodeNormalized
                .lowercased()


        let simplified =
            simplifyCharacters(
                lowercase
            )


        let words =
            normalizeSeparators(
                simplified
            )


        let tokens =
            words
                .split(
                    separator: " "
                )
                .map(
                    String.init
                )


        let compact =
            tokens.joined()


        return NormalizedContent(
            words: words,
            compact: compact,
            tokens: tokens,
            original: text
        )
    }


    // MARK: - Unicode Normalization

    private static func normalizeUnicode(
        _ text: String
    ) -> String {

        text
            .precomposedStringWithCompatibilityMapping
            .folding(
                options: [
                    .diacriticInsensitive,
                    .widthInsensitive
                ],
                locale:
                    Locale(
                        identifier:
                            "en_US_POSIX"
                    )
            )
    }


    // MARK: - Character Simplification

    private static func simplifyCharacters(
        _ text: String
    ) -> String {

        var result = ""


        result.reserveCapacity(
            text.count
        )


        for character in text {

            if let replacement =
                replacementForCharacter(
                    character
                ) {

                result.append(
                    replacement
                )

            } else {

                result.append(
                    character
                )
            }
        }


        return result
    }


    private static func replacementForCharacter(
        _ character: Character
    ) -> Character? {

        /*
         Global substitutions remain deliberately
         conservative.

         Aggressive leetspeak conversion can produce
         false positives in otherwise harmless text.
        */

        switch character {

        case "@":
            return "a"

        case "$":
            return "s"

        default:
            return nil
        }
    }

    private static func replacementForObfuscatedCharacter(
        _ character: Character
    ) -> Character? {

        switch character {

        case "@", "4":
            return "a"

        case "3":
            return "e"

        case "1", "!":
            return "i"

        case "0":
            return "o"

        case "$", "5":
            return "s"

        case "7":
            return "t"

        default:
            return nil
        }
    }

    private static func normalizeObfuscated(
        _ text: String
    ) -> String {

        let unicodeNormalized =
            normalizeUnicode(text)
                .lowercased()

        var result = ""

        for character in unicodeNormalized {

            if let replacement =
                replacementForObfuscatedCharacter(
                    character
                ) {

                result.append(
                    replacement
                )

            } else if character.isLetter ||
                        character.isNumber {

                result.append(
                    character
                )
            }
        }

        return result
    }



    // MARK: - Separator Normalization

    private static func normalizeSeparators(
        _ text: String
    ) -> String {

        var result = ""

        var previousWasSeparator =
            false


        for scalar in
            text.unicodeScalars {

            if shouldPreserve(
                scalar
            ) {

                result
                    .unicodeScalars
                    .append(
                        scalar
                    )


                previousWasSeparator =
                    false

            } else if
                !previousWasSeparator,
                !result.isEmpty {

                result.append(
                    " "
                )


                previousWasSeparator =
                    true
            }
        }


        return result
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
    }


    private static func shouldPreserve(
        _ scalar: UnicodeScalar
    ) -> Bool {

        CharacterSet
            .alphanumerics
            .contains(
                scalar
            )
    }
}
