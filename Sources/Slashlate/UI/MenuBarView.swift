import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Slashlate")
                    .font(.headline)

                Spacer()

                Text("M0")
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

            Text("M0 test")
                .font(.caption)
                .fontWeight(.semibold)

            Text(
                "Type some text followed by " + appState.trigger +
                ". Slashlate should replace the entire focused field with TEST TRANSLATION."
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
}
