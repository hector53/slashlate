import AppKit
import Foundation

final class AppState: ObservableObject {
    @Published var isEnabled = true
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var isMonitoring = false
    @Published private(set) var statusMessage = "Starting Slashlate..."

    let trigger = "///"

    private let accessibilityService = AccessibilityService()
    private var keyboardMonitor: KeyboardMonitor?
    private var permissionTimer: Timer?

    init() {
        DispatchQueue.main.async { [weak self] in
            self?.start()
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
                self?.refreshAccessibility(prompt: false)
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
            self?.handleTrigger()
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

        statusMessage = "Trigger detected..."

        do {
            let result = try accessibilityService.replaceCurrentFieldIfTriggered(
                trigger: trigger,
                replacement: "TEST TRANSLATION"
            )

            switch result {
            case .replaced:
                statusMessage = "M0 replacement succeeded"
            case .triggerNotAtEnd:
                statusMessage = "Trigger detected, but the focused field changed"
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
