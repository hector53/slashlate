import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var isEnabled = true
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var isMonitoring = false
    @Published private(set) var isTranslating = false
    @Published private(set) var hasAPIKey = false
    @Published private(set) var statusMessage = "Starting Slashlate..."

    let trigger = "///"

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
            statusMessage = "API key is empty"
            return false
        }

        do {
            try apiKeyStore.save(apiKey)
            hasAPIKey = true
            statusMessage = "OpenRouter API key saved"
            return true
        } catch {
            statusMessage = "Could not save the API key: " + error.localizedDescription
            return false
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
            statusMessage = "Accessibility permission required"
        }
    }

    private func startKeyboardMonitorIfNeeded() {
        guard keyboardMonitor == nil else {
            return
        }

        let monitor = KeyboardMonitor(trigger: trigger) { [weak self] in
            MainActor.assumeIsolated {
                self?.handleTrigger()
            }
        }

        guard monitor.start() else {
            statusMessage = "Could not start the global keyboard monitor"
            return
        }

        keyboardMonitor = monitor
        isMonitoring = true
        statusMessage = "Ready - type " + trigger + " at the end of a text field"
    }

    private func stopKeyboardMonitor() {
        keyboardMonitor?.stop()
        keyboardMonitor = nil
        isMonitoring = false
    }

    private func handleTrigger() {
        guard isEnabled else {
            return
        }

        guard activeTranslation == nil else {
            statusMessage = "Translating... (ignored new trigger)"
            return
        }

        let field: FocusedTextField
        do {
            field = try accessibilityService.captureFocusedTextField()
        } catch {
            statusMessage = error.localizedDescription
            return
        }

        guard let triggeredText = TriggeredText(fieldValue: field.value, trigger: trigger) else {
            statusMessage = "Trigger detected, but the focused field changed"
            return
        }

        guard triggeredText.hasTextToTranslate else {
            statusMessage = "Nothing to translate"
            return
        }

        // The visible text (including the trigger) is left untouched until a
        // valid translation arrives and the field is verified unchanged.
        isTranslating = true
        statusMessage = "Translating..."

        activeTranslation = Task { [weak self, translationService] in
            let result: Result<String, Error>
            do {
                result = .success(try await translationService.translate(triggeredText.sourceText))
            } catch {
                result = .failure(error)
            }

            self?.finishTranslation(result, field: field, triggeredText: triggeredText)
        }
    }

    private func finishTranslation(
        _ result: Result<String, Error>,
        field: FocusedTextField,
        triggeredText: TriggeredText
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
            statusMessage = error.localizedDescription
            return
        }

        do {
            let decision = try accessibilityService.replaceText(
                in: field,
                expectedValue: triggeredText.originalValue,
                with: translation
            )

            switch decision {
            case .replace:
                statusMessage = "Translated"
            case .focusChanged:
                statusMessage = "Translation discarded - focus moved to another field"
            case .textChanged:
                statusMessage = "Translation discarded - the text changed while translating"
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
