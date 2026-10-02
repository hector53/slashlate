/// A focused-field value that ended with the trigger when it was captured.
///
/// `originalValue` is what the field must still contain before Slashlate is
/// allowed to replace it. `sourceText` is what gets sent to the model.
struct TriggeredText: Equatable {
    let originalValue: String
    let sourceText: String

    init?(fieldValue: String, trigger: String) {
        guard !trigger.isEmpty, fieldValue.hasSuffix(trigger) else {
            return nil
        }

        originalValue = fieldValue
        sourceText = String(fieldValue.dropLast(trigger.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasTextToTranslate: Bool {
        !sourceText.isEmpty
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
