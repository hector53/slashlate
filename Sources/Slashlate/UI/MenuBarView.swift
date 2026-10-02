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

                Text("M1.1")
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

            Text(appState.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
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

            Text(
                "Type Spanish text followed by " + TranslationTrigger.wholeField.sequence +
                " to translate the whole field, or " + TranslationTrigger.currentLine.sequence +
                " to translate only the current line. Slashlate never sends the message."
            )
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

    private func saveAPIKey() {
        if appState.saveAPIKey(apiKeyDraft) {
            apiKeyDraft = ""
            isEditingAPIKey = false
        }
    }
}
