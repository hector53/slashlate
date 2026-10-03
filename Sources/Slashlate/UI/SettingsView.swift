import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }

            HotkeySettings(appState: appState)
                .tabItem { Label("Hotkey", systemImage: "keyboard") }

            OpenRouterSettings(appState: appState)
                .tabItem { Label("OpenRouter", systemImage: "key") }
        }
        .frame(width: 460)
        .padding(20)
    }
}

private struct GeneralSettings: View {
    @State private var launchState = LaunchAtLogin.state
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Toggle("Open Slashlate at login", isOn: Binding(
                get: { launchState != .disabled },
                set: setLaunchAtLogin
            ))

            if launchState == .requiresApproval {
                Text("Allow Slashlate in System Settings → General → Login Items.")
                    .foregroundStyle(.orange)
                Button("Open Login Items") {
                    LaunchAtLogin.openSystemSettings()
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            launchState = LaunchAtLogin.state
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            errorMessage = nil
        } catch {
            errorMessage = "Could not change the login item: " + error.localizedDescription
        }
        launchState = LaunchAtLogin.state
    }
}

private struct HotkeySettings: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Form {
            LabeledContent("Translate") {
                HotkeyRecorder(appState: appState)
            }

            Text("Translates the selected text, or the whole field if nothing is selected.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct OpenRouterSettings: View {
    @ObservedObject var appState: AppState
    @State private var apiKeyDraft = ""
    @State private var isEditingAPIKey = false

    var body: some View {
        Form {
            if appState.hasAPIKey && !isEditingAPIKey {
                LabeledContent("API key") {
                    Label("Configured", systemImage: "checkmark.circle.fill")
                }

                Button("Replace API Key") {
                    apiKeyDraft = ""
                    isEditingAPIKey = true
                }
            } else {
                SecureField("API key", text: $apiKeyDraft, prompt: Text("sk-or-..."))
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

            Text("Stored only in your macOS Keychain.")
                .foregroundStyle(.secondary)
        }
    }

    private func saveAPIKey() {
        if appState.saveAPIKey(apiKeyDraft) {
            apiKeyDraft = ""
            isEditingAPIKey = false
        }
    }
}
