import AppKit
import ApplicationServices
import OSLog

/// The focused text element and its value at the moment the trigger fired.
///
/// The element reference is kept so the translation is written back to this
/// exact element, never to whatever happens to be focused later.
struct FocusedTextField {
    let element: AXUIElement
    let value: String
    /// `AXSelectedTextRange` in UTF-16 units, or nil if the control does not
    /// expose it.
    let selectedUTF16Range: Range<Int>?
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
    /// Diagnostics for the Electron fallback. Logs only AX error codes and
    /// bundle IDs, never field contents. View with:
    /// `log stream --predicate 'subsystem == "dev.hectoracosta.slashlate"'`
    private let logger = Logger(subsystem: "dev.hectoracosta.slashlate", category: "accessibility")

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

        return FocusedTextField(
            element: focusedElement,
            value: text,
            selectedUTF16Range: readSelectedRange(of: focusedElement)
        )
    }

    /// Writes `replacement` to the captured field only if it is still focused
    /// and still contains exactly `expectedValue`. Otherwise the field is left
    /// untouched.
    func replaceText(
        in field: FocusedTextField,
        expectedValue: String,
        with replacement: FieldReplacement
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
            replacement.value as CFString
        )

        guard writeError == .success else {
            throw AccessibilityServiceError.writeFailed(writeError)
        }

        if let cursorOffset = replacement.cursorUTF16Offset {
            // Best effort: the text is already written, so a control that
            // rejects this just keeps its own cursor position.
            var range = CFRange(location: cursorOffset, length: 0)
            if let rangeValue = AXValueCreate(.cfRange, &range) {
                AXUIElementSetAttributeValue(
                    field.element,
                    kAXSelectedTextRangeAttribute as CFString,
                    rangeValue
                )
            }
        }

        return .replace
    }

    private func readSelectedRange(of element: AXUIElement) -> Range<Int>? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        )

        guard error == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range),
              range.location >= 0,
              range.length >= 0
        else {
            return nil
        }

        return range.location..<(range.location + range.length)
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

    /// Returns the focused element. Native apps answer the system-wide query.
    /// Electron apps (Slack, Discord, ...) do not build their accessibility
    /// tree until asked through `AXManualAccessibility`, so the system-wide
    /// query fails with `kAXErrorNoValue`; in that case the frontmost app is
    /// asked to expose it and queried directly.
    private func getFocusedElement() throws -> AXUIElement {
        let (focused, systemWideError) = copyFocusedElement(of: AXUIElementCreateSystemWide())
        if let focused {
            return focused
        }

        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            throw AccessibilityServiceError.focusedElementUnavailable(systemWideError)
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // The tree is built asynchronously after the first enable, so retry
        // briefly. Later lookups for the same app need no wait.
        let bundleID = app.bundleIdentifier ?? "unknown"
        let attempts = enableManualAccessibility(on: appElement, pid: app.processIdentifier) ? 6 : 1
        var lastError = AXError.success
        for attempt in 1...attempts {
            let (focused, error) = copyFocusedElement(of: appElement)
            if let focused {
                logger.info("\(bundleID, privacy: .public): focused element via app fallback (attempt \(attempt))")
                return focused
            }
            lastError = error
            if attempt < attempts {
                Thread.sleep(forTimeInterval: 0.03)
            }
        }

        let windowError = attributeError(kAXFocusedWindowAttribute, of: appElement)
        let manualError = attributeError("AXManualAccessibility", of: appElement)
        let enhancedError = attributeError("AXEnhancedUserInterface", of: appElement)
        logger.error(
            "\(bundleID, privacy: .public): no focused element. system-wide AX \(systemWideError.rawValue), app AX \(lastError.rawValue) after \(attempts) attempt(s), focused window AX \(windowError.rawValue), AXManualAccessibility read AX \(manualError.rawValue), AXEnhancedUserInterface read AX \(enhancedError.rawValue)"
        )

        throw AccessibilityServiceError.focusedElementUnavailable(systemWideError)
    }

    private func copyFocusedElement(of element: AXUIElement) -> (element: AXUIElement?, error: AXError) {
        var focusedValue: CFTypeRef?

        let focusedError = AXUIElementCopyAttributeValue(
            element,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard focusedError == .success, let focusedValue else {
            return (nil, focusedError)
        }

        return ((focusedValue as! AXUIElement), .success)
    }

    private func attributeError(_ attribute: String, of element: AXUIElement) -> AXError {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    }

    /// Process IDs Slashlate already asked to expose their accessibility tree.
    private var accessibilityRequestedPIDs: Set<pid_t> = []

    /// Asks a Chromium/Electron app to expose its accessibility tree. Returns
    /// true only the first time for that process, so the caller waits for the
    /// tree to be built once.
    ///
    /// `AXManualAccessibility` is Electron's dedicated switch (Slack). Some
    /// Electron builds reject it (the ChatGPT macOS app: AX -25205);
    /// `AXEnhancedUserInterface`, the flag screen readers set, is tried too.
    /// Chromium may build its tree even when that call reports an error
    /// (ChatGPT: AX -25208), so the result is not trusted either way.
    private func enableManualAccessibility(on appElement: AXUIElement, pid: pid_t) -> Bool {
        guard accessibilityRequestedPIDs.insert(pid).inserted else {
            return false
        }

        for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
            let error = AXUIElementSetAttributeValue(appElement, attribute as CFString, kCFBooleanTrue)
            logger.info("pid \(pid): set \(attribute, privacy: .public) -> AX \(error.rawValue)")
            if error == .success {
                break
            }
        }

        return true
    }
}
