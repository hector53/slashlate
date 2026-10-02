import ApplicationServices

/// The focused text element and its value at the moment the trigger fired.
///
/// The element reference is kept so the translation is written back to this
/// exact element, never to whatever happens to be focused later.
struct FocusedTextField {
    let element: AXUIElement
    let value: String
}

enum AccessibilityServiceError: LocalizedError {
    case permissionRequired
    case focusedElementUnavailable(AXError)
    case valueUnavailable(AXError)
    case unsupportedTextValue
    case valueNotSettable
    case writeFailed(AXError)

    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            return "Slashlate needs Accessibility permission"
        case .focusedElementUnavailable(let error):
            return "Could not read the focused text field (AX " + String(error.rawValue) + ")"
        case .valueUnavailable(let error):
            return "Could not read text from the focused field (AX " + String(error.rawValue) + ")"
        case .unsupportedTextValue:
            return "The focused control does not expose a plain text value"
        case .valueNotSettable:
            return "The focused text field is not writable through Accessibility"
        case .writeFailed(let error):
            return "Could not replace the focused text (AX " + String(error.rawValue) + ")"
        }
    }
}

final class AccessibilityService {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    func requestTrust() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Reads the focused element and verifies it is a writable plain-text field.
    /// Nothing is modified.
    func captureFocusedTextField() throws -> FocusedTextField {
        guard isTrusted else {
            throw AccessibilityServiceError.permissionRequired
        }

        let focusedElement = try getFocusedElement()
        let text = try readValue(of: focusedElement)

        var settable = DarwinBoolean(false)
        let settableError = AXUIElementIsAttributeSettable(
            focusedElement,
            kAXValueAttribute as CFString,
            &settable
        )

        guard settableError == .success, settable.boolValue else {
            throw AccessibilityServiceError.valueNotSettable
        }

        return FocusedTextField(element: focusedElement, value: text)
    }

    /// Replaces the captured field only if it is still focused and still
    /// contains exactly `expectedValue`. Otherwise the field is left untouched.
    func replaceText(
        in field: FocusedTextField,
        expectedValue: String,
        with replacement: String
    ) throws -> ReplacementDecision {
        guard isTrusted else {
            throw AccessibilityServiceError.permissionRequired
        }

        let currentFocus = try? getFocusedElement()
        let isSameFocusedElement = currentFocus.map { CFEqual($0, field.element) } ?? false
        let currentValue = isSameFocusedElement ? try? readValue(of: field.element) : nil

        let decision = ReplacementDecision(
            originalValue: expectedValue,
            isSameFocusedElement: isSameFocusedElement,
            currentValue: currentValue
        )

        guard decision == .replace else {
            return decision
        }

        let writeError = AXUIElementSetAttributeValue(
            field.element,
            kAXValueAttribute as CFString,
            replacement as CFString
        )

        guard writeError == .success else {
            throw AccessibilityServiceError.writeFailed(writeError)
        }

        return .replace
    }

    private func readValue(of element: AXUIElement) throws -> String {
        var value: CFTypeRef?
        let valueError = AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &value
        )

        guard valueError == .success else {
            throw AccessibilityServiceError.valueUnavailable(valueError)
        }

        guard let text = value as? String else {
            throw AccessibilityServiceError.unsupportedTextValue
        }

        return text
    }

    private func getFocusedElement() throws -> AXUIElement {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?

        let focusedError = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard focusedError == .success, let focusedValue else {
            throw AccessibilityServiceError.focusedElementUnavailable(focusedError)
        }

        return focusedValue as! AXUIElement
    }
}
