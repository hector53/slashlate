import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @State private var apiKeyDraft = ""
    @State private var isEditingAPIKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Slashlate")
                    .font(.headline)

                Spacer()

                Text("M2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Enabled", isOn: $appState.isEnabled)

            Divider()

            Label(
                appState.accessibilityGranted
                    ? "Accessibility granted"
                    : "Accessibility required",
                systemImage: appState.accessibilityGranted
                    ? "checkmark.circle.fill"
                    : "exclamationmark.triangle.fill"
            )

            Label(appState.statusMessage, systemImage: appState.statusKind.symbol)
                .font(.callout)
                .foregroundStyle(appState.statusKind.color)
                .fixedSize(horizontal: false, vertical: true)

            if !appState.accessibilityGranted {
                Button("Grant Accessibility Permission") {
                    appState.requestAccessibilityPermission()
                }
            }

            Button("Open Accessibility Settings") {
                appState.openAccessibilitySettings()
            }

            Divider()

            apiKeySection

            Divider()

            Text(helpText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Divider()

            Button("Quit Slashlate") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 320)
        // The popover is this app's only window: opening or closing it means
        // the current status has been seen.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            appState.markStatusSeen()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            appState.markStatusSeen()
        }
    }

    @ViewBuilder
    private var apiKeySection: some View {
        Text("OpenRouter API Key")
            .font(.caption)
            .fontWeight(.semibold)

        if appState.hasAPIKey && !isEditingAPIKey {
            Label("Configured", systemImage: "checkmark.circle.fill")

            Button("Replace API Key") {
                apiKeyDraft = ""
                isEditingAPIKey = true
            }
        } else {
            SecureField("sk-or-...", text: $apiKeyDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit(saveAPIKey)

            HStack {
                Button("Save API Key", action: saveAPIKey)
                    .disabled(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if appState.hasAPIKey {
                    Button("Cancel") {
                        apiKeyDraft = ""
                        isEditingAPIKey = false
                    }
                }
            }
        }
    }

    private var helpText: String {
        let wholeField = TranslationTrigger.wholeField.sequence
        let currentLine = TranslationTrigger.currentLine.sequence
        let hotkey = appState.hotkey.displayName
        return "Type Spanish text followed by \(wholeField) to translate the whole field, "
            + "or \(currentLine) to translate only the current line. "
            + "Press \(hotkey) to translate the selection, or the whole field if nothing is selected. "
            + "Slashlate never sends the message."
    }

    private func saveAPIKey() {
        if appState.saveAPIKey(apiKeyDraft) {
            apiKeyDraft = ""
            isEditingAPIKey = false
        }
    }
}

private extension StatusKind {
    var symbol: String {
        switch self {
        case .info: return "info.circle"
        case .translating: return "ellipsis.circle"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .info, .translating: return .secondary
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}
