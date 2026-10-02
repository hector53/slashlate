import AppKit
import Foundation

enum StatusKind: Equatable {
    case info
    case translating
    case success
    /// Nothing was written, by design (text changed, focus moved, nothing to translate).
    case warning
    /// Something failed (API, network, Accessibility).
    case error

    var isAlert: Bool {
        self == .warning || self == .error
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var isEnabled = true
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var isMonitoring = false
    @Published private(set) var isTranslating = false
    @Published private(set) var hasAPIKey = false
    @Published private(set) var statusMessage = "Starting Slashlate..."
    @Published private(set) var statusKind = StatusKind.info
    /// A warning or error the user has not seen yet. Drives the menu-bar icon
    /// so failures are visible without opening the popover.
    @Published private(set) var hasUnseenAlert = false

    let triggers = TranslationTrigger.all

    private let accessibilityService = AccessibilityService()
    private let apiKeyStore: CachedKeychainValue
    private let translationService: TranslationService
    private var keyboardMonitor: KeyboardMonitor?
    private var permissionTimer: Timer?

    /// M1 policy: at most one translation in flight. A trigger that fires
    /// while this is non-nil is ignored instead of starting a second request.
    private var activeTranslation: Task<Void, Never>?

    init() {
        let apiKeyStore = CachedKeychainValue(keychain: .openRouterAPIKey)
        self.apiKeyStore = apiKeyStore
        translationService = OpenRouterTranslationService(apiKeyProvider: {
            try apiKeyStore.read()
        })
        hasAPIKey = apiKeyStore.hasValue

        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.start()
            }
        }
    }

    @discardableResult
    func saveAPIKey(_ rawValue: String) -> Bool {
        let apiKey = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !apiKey.isEmpty else {
            setStatus("API key is empty", .warning)
            return false
        }

        do {
            try apiKeyStore.save(apiKey)
            hasAPIKey = true
            setStatus("OpenRouter API key saved", .success)
            return true
        } catch {
            setStatus("Could not save the API key: " + error.localizedDescription, .error)
            return false
        }
    }

    /// Called when the popover opens or closes: whatever it showed has been seen.
    func markStatusSeen() {
        hasUnseenAlert = false
    }

    private func setStatus(_ message: String, _ kind: StatusKind) {
        statusMessage = message
        statusKind = kind
        if kind.isAlert {
            hasUnseenAlert = true
        }
    }

    func requestAccessibilityPermission() {
        refreshAccessibility(prompt: true)
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func start() {
        refreshAccessibility(prompt: true)

        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.refreshAccessibility(prompt: false)
                }
            }
        }
    }

    private func refreshAccessibility(prompt: Bool) {
        let trusted = prompt
            ? accessibilityService.requestTrust()
            : accessibilityService.isTrusted

        accessibilityGranted = trusted

        if trusted {
            startKeyboardMonitorIfNeeded()
        } else {
            stopKeyboardMonitor()
            setStatus("Accessibility permission required", .error)
        }
    }

    private func startKeyboardMonitorIfNeeded() {
        guard keyboardMonitor == nil else {
            return
        }

        let monitor = KeyboardMonitor(triggers: triggers) { [weak self] trigger in
            MainActor.assumeIsolated {
                self?.handleTrigger(trigger)
            }
        }

        guard monitor.start() else {
            setStatus("Could not start the global keyboard monitor", .error)
            return
        }

        keyboardMonitor = monitor
        isMonitoring = true
        setStatus(
            "Ready - type " + TranslationTrigger.wholeField.sequence
                + " (whole field) or " + TranslationTrigger.currentLine.sequence + " (current line)",
            .info
        )
    }

    private func stopKeyboardMonitor() {
        keyboardMonitor?.stop()
        keyboardMonitor = nil
        isMonitoring = false
    }

    private func handleTrigger(_ trigger: TranslationTrigger) {
        guard isEnabled else {
            return
        }

        guard activeTranslation == nil else {
            setStatus("Translating... (ignored new trigger)", .translating)
            return
        }

        let field: FocusedTextField
        do {
            field = try accessibilityService.captureFocusedTextField()
        } catch {
            setStatus(error.localizedDescription, .error)
            return
        }

        let target: TranslationTarget
        do {
            target = try TranslationTarget(
                trigger: trigger,
                fieldValue: field.value,
                selectedUTF16Range: field.selectedUTF16Range
            )
        } catch {
            setStatus(error.localizedDescription, .warning)
            return
        }

        // The visible text (including the trigger) is left untouched until a
        // valid translation arrives and the field is verified unchanged.
        isTranslating = true
        setStatus("Translating...", .translating)

        activeTranslation = Task { [weak self, translationService] in
            let result: Result<String, Error>
            do {
                result = .success(try await translationService.translate(target.sourceText))
            } catch {
                result = .failure(error)
            }

            self?.finishTranslation(result, field: field, target: target)
        }
    }

    private func finishTranslation(
        _ result: Result<String, Error>,
        field: FocusedTextField,
        target: TranslationTarget
    ) {
        defer {
            activeTranslation = nil
            isTranslating = false
        }

        let translation: String
        switch result {
        case .success(let value):
            translation = value
        case .failure(let error):
            setStatus(error.localizedDescription, .error)
            return
        }

        do {
            let decision = try accessibilityService.replaceText(
                in: field,
                expectedValue: target.originalValue,
                with: target.replacement(with: translation)
            )

            switch decision {
            case .replace:
                setStatus("Translated", .success)
            case .focusChanged:
                setStatus("Translation discarded - focus moved to another field", .warning)
            case .textChanged:
                setStatus("Translation discarded - the text changed while translating", .warning)
            }
        } catch {
            setStatus(error.localizedDescription, .error)
        }
    }
}
