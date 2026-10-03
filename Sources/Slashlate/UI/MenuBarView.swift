import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

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

            Label(
                appState.hasAPIKey ? "OpenRouter API key configured" : "OpenRouter API key missing",
                systemImage: appState.hasAPIKey ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
            )
            .foregroundStyle(appState.hasAPIKey ? Color.primary : Color.orange)

            Button("Settings…", action: showSettings)

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

    private func showSettings() {
        // The popover is the key window while its button is clicked.
        let popover = NSApp.keyWindow

        // A menu-bar app is not active by default; without this the
        // Settings window can open behind the frontmost app.
        NSApp.activate()
        openSettings()
        popover?.close()

        // The Settings window exists only after openSettings() returns.
        DispatchQueue.main.async {
            guard let settings = NSApp.windows.first(where: {
                $0.identifier?.rawValue == "com_apple_SwiftUI_Settings_window"
            }) else {
                return
            }
            settings.center()
            settings.makeKeyAndOrderFront(nil)
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
