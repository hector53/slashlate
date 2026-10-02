import Foundation

enum TranslationTargetError: LocalizedError, Equatable {
    /// The trigger is not where it must be (end of field / right before the cursor).
    case triggerNotFound
    /// The control does not report a usable cursor position.
    case cursorUnavailable
    case nothingToTranslate

    var errorDescription: String? {
        switch self {
        case .triggerNotFound:
            return "Trigger detected, but the focused field changed"
        case .cursorUnavailable:
            return "This field does not report the cursor position - use /// instead"
        case .nothingToTranslate:
            return "Nothing to translate"
        }
    }
}

/// The new field value to write, and where to leave the cursor afterwards.
struct FieldReplacement: Equatable {
    let value: String
    /// UTF-16 cursor position to restore, or nil to leave it to the app.
    let cursorUTF16Offset: Int?
}

/// What a trigger asked Slashlate to translate, captured when it fired.
///
/// `originalValue` is what the field must still contain before Slashlate is
/// allowed to write. `sourceText` is what gets sent to the model.
/// `replacementRange` is the part of `originalValue` the translation replaces;
/// everything outside it is written back byte-for-byte.
struct TranslationTarget: Equatable {
    let scope: TranslationScope
    let originalValue: String
    let sourceText: String
    let replacementRange: Range<String.Index>

    /// - Parameters:
    ///   - selectedUTF16Range: the field's `AXSelectedTextRange` in UTF-16
    ///     units, or nil if the control does not expose it. Only used by
    ///     `.currentLine`.
    init(
        trigger: TranslationTrigger,
        fieldValue: String,
        selectedUTF16Range: Range<Int>?
    ) throws {
        switch trigger.scope {
        case .wholeField:
            guard fieldValue.hasSuffix(trigger.sequence) else {
                throw TranslationTargetError.triggerNotFound
            }

            sourceText = String(fieldValue.dropLast(trigger.sequence.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            replacementRange = fieldValue.startIndex..<fieldValue.endIndex

        case .currentLine:
            let line = try Self.currentLine(
                in: fieldValue,
                trigger: trigger.sequence,
                selectedUTF16Range: selectedUTF16Range
            )
            sourceText = line.sourceText
            replacementRange = line.replacementRange
        }

        guard !sourceText.isEmpty else {
            throw TranslationTargetError.nothingToTranslate
        }

        scope = trigger.scope
        originalValue = fieldValue
    }

    /// The full field value with only `replacementRange` swapped for `translation`.
    func replacement(with translation: String) -> FieldReplacement {
        var value = originalValue
        value.replaceSubrange(replacementRange, with: translation)

        switch scope {
        case .wholeField:
            // Same as M1: write the value and let the app place the cursor.
            return FieldReplacement(value: value, cursorUTF16Offset: nil)
        case .currentLine:
            // Keep the cursor at the end of the translated line instead of
            // wherever the app puts it after a full value write.
            let prefix = originalValue[..<replacementRange.lowerBound]
            return FieldReplacement(
                value: value,
                cursorUTF16Offset: prefix.utf16.count + translation.utf16.count
            )
        }
    }

    private static func currentLine(
        in value: String,
        trigger: String,
        selectedUTF16Range: Range<Int>?
    ) throws -> (sourceText: String, replacementRange: Range<String.Index>) {
        // A selection (non-empty range) is not a plain cursor: refuse.
        guard let selection = selectedUTF16Range else {
            throw TranslationTargetError.cursorUnavailable
        }

        guard selection.isEmpty,
              let cursor = stringIndex(atUTF16Offset: selection.lowerBound, in: value)
        else {
            throw TranslationTargetError.triggerNotFound
        }

        // The trigger must sit immediately before the cursor.
        let beforeCursor = value[..<cursor]
        guard beforeCursor.hasSuffix(trigger) else {
            throw TranslationTargetError.triggerNotFound
        }

        let triggerStart = beforeCursor.dropLast(trigger.count).endIndex

        // "scheme://." is a URL being typed, not a trigger.
        if triggerStart > value.startIndex, value[value.index(before: triggerStart)] == ":" {
            throw TranslationTargetError.triggerNotFound
        }

        let lineStart = value[..<triggerStart].lastIndex(where: \.isNewline)
            .map { value.index(after: $0) } ?? value.startIndex
        let lineEnd = value[cursor...].firstIndex(where: \.isNewline) ?? value.endIndex

        // Keep the line's indentation; replace from its first visible character.
        let contentStart = value[lineStart..<triggerStart].firstIndex(where: { !$0.isWhitespace })
            ?? triggerStart

        let sourceText = (value[contentStart..<triggerStart] + value[cursor..<lineEnd])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (sourceText, contentStart..<lineEnd)
    }

    /// Converts an AX UTF-16 offset into a `String.Index` on a character
    /// boundary, or nil if it is out of bounds or splits a character.
    private static func stringIndex(atUTF16Offset offset: Int, in value: String) -> String.Index? {
        guard offset >= 0, offset <= value.utf16.count else {
            return nil
        }

        let utf16Index = value.utf16.index(value.utf16.startIndex, offsetBy: offset)
        return utf16Index.samePosition(in: value)
    }
}

/// Whether a translation that just arrived may be written back.
enum ReplacementDecision: Equatable {
    case replace
    case focusChanged
    case textChanged

    init(originalValue: String, isSameFocusedElement: Bool, currentValue: String?) {
        guard isSameFocusedElement else {
            self = .focusChanged
            return
        }

        guard currentValue == originalValue else {
            self = .textChanged
            return
        }

        self = .replace
    }
}
