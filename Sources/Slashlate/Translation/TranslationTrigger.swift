/// How much of the focused field a trigger translates.
enum TranslationScope: Equatable {
    /// The whole field value (M1 behavior).
    case wholeField
    /// Only the line that contains the cursor.
    case currentLine
}

/// A typed character sequence that starts a translation.
///
/// This is the single place where triggers and their scopes are defined.
struct TranslationTrigger: Equatable {
    let sequence: String
    let scope: TranslationScope

    static let wholeField = TranslationTrigger(sequence: "///", scope: .wholeField)
    static let currentLine = TranslationTrigger(sequence: "//.", scope: .currentLine)

    static let all: [TranslationTrigger] = [.wholeField, .currentLine]
}
