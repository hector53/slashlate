/// How much of the focused field a translation covers.
enum TranslationScope: Equatable {
    /// The whole field value (M1 behavior).
    case wholeField
    /// Only the line that contains the cursor.
    case currentLine
    /// Only the selected text (hotkey with a selection).
    case selection
}

/// What started a translation. `TranslationTarget` turns it into a scope.
enum TranslationRequest: Equatable {
    /// A trigger typed at the cursor (`///`, `//.`).
    case typed(TranslationTrigger)
    /// The global hotkey: the selection if there is one, else the whole field.
    case hotkey
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
