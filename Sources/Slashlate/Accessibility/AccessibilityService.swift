import ApplicationServices

enum AccessibilityReplacementResult {
    case replaced
    case triggerNotAtEnd
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

    func replaceCurrentFieldIfTriggered(
        trigger: String,
        replacement: String
    ) throws -> AccessibilityReplacementResult {
        guard isTrusted else {
            throw AccessibilityServiceError.permissionRequired
        }

        let focusedElement = try getFocusedElement()

        var value: CFTypeRef?
        let valueError = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXValueAttribute as CFString,
            &value
        )

        guard valueError == .success else {
            throw AccessibilityServiceError.valueUnavailable(valueError)
        }

        guard let text = value as? String else {
            throw AccessibilityServiceError.unsupportedTextValue
        }

        guard text.hasSuffix(trigger) else {
            return .triggerNotAtEnd
        }

        var settable = DarwinBoolean(false)
        let settableError = AXUIElementIsAttributeSettable(
            focusedElement,
            kAXValueAttribute as CFString,
            &settable
        )

        guard settableError == .success, settable.boolValue else {
            throw AccessibilityServiceError.valueNotSettable
        }

        let writeError = AXUIElementSetAttributeValue(
            focusedElement,
            kAXValueAttribute as CFString,
            replacement as CFString
        )

        guard writeError == .success else {
            throw AccessibilityServiceError.writeFailed(writeError)
        }

        return .replaced
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
