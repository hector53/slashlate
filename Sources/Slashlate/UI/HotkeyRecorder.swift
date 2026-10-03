import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Click, then press a shortcut. Esc cancels.
struct HotkeyRecorder: View {
    @ObservedObject var appState: AppState
    @State private var isRecording = false
    @State private var eventMonitor: Any?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: toggleRecording) {
                    Text(isRecording ? "Press a shortcut…" : appState.hotkey.displayName)
                        .frame(minWidth: 140)
                }
                .controlSize(.large)

                Button("Reset to " + TranslationHotkey.translate.displayName) {
                    appState.beginHotkeyRecording()
                    message = appState.endHotkeyRecording(with: .translate)
                }
                .disabled(isRecording || appState.hotkey == .translate)
            }

            if let message {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if isRecording {
                Text("Use ⌃ or ⌥ (optionally with ⇧ or ⌘). Esc cancels.")
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear {
            if isRecording {
                finish(with: nil)
            }
        }
    }

    private func toggleRecording() {
        if isRecording {
            finish(with: nil)
            return
        }

        message = nil
        isRecording = true
        appState.beginHotkeyRecording()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape {
                finish(with: nil)
            } else if let hotkey = TranslationHotkey(event: event) {
                finish(with: hotkey)
            } else {
                message = "Use ⌃ or ⌥ in the shortcut, so it does not replace an app shortcut like ⌘C."
            }
            // Swallow the key so it is not typed anywhere while recording.
            return nil
        }
    }

    private func finish(with hotkey: TranslationHotkey?) {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil
        isRecording = false

        let error = appState.endHotkeyRecording(with: hotkey)
        if hotkey != nil || error != nil {
            message = error
        }
    }
}

extension TranslationHotkey {
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }

        self.init(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyLabel: Self.label(for: event))
    }

    private static let specialKeyLabels: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_Home: "↖", kVK_End: "↘",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static func label(for event: NSEvent) -> String {
        if let special = specialKeyLabels[Int(event.keyCode)] {
            return special
        }
        return (event.charactersIgnoringModifiers ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }
}
