import Carbon.HIToolbox

/// A global keyboard shortcut. The default is defined once, here.
struct TranslationHotkey: Equatable, Codable {
    /// Carbon virtual key code (physical key position, layout independent).
    let keyCode: UInt32
    /// Carbon modifier mask (`controlKey`, `optionKey`, `shiftKey`, `cmdKey`).
    let modifiers: UInt32
    /// The key as shown in the UI ("T", "Space", "F5").
    let keyLabel: String

    static let translate = TranslationHotkey(
        keyCode: UInt32(kVK_ANSI_T),
        modifiers: UInt32(controlKey | optionKey),
        keyLabel: "T"
    )!

    /// Returns nil unless the shortcut uses ⌃ or ⌥. A global hotkey steals
    /// the key press from every app, so ⌘-only or ⇧-only shortcuts (⌘C, ⌘T)
    /// would break common app shortcuts.
    init?(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        let required = UInt32(controlKey | optionKey)
        let supported = UInt32(controlKey | optionKey | shiftKey | cmdKey)

        guard modifiers & required != 0, modifiers & ~supported == 0, !keyLabel.isEmpty else {
            return nil
        }

        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    /// Standard macOS order: ⌃⌥⇧⌘ then the key.
    var displayName: String {
        let symbols: [(Int, String)] = [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
        return symbols
            .filter { modifiers & UInt32($0.0) != 0 }
            .map(\.1)
            .joined() + keyLabel
    }

    // Decoding goes through the validating initializer, so an invalid stored
    // value falls back to the default instead of registering a bad shortcut.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let hotkey = TranslationHotkey(
            keyCode: try container.decode(UInt32.self, forKey: .keyCode),
            modifiers: try container.decode(UInt32.self, forKey: .modifiers),
            keyLabel: try container.decode(String.self, forKey: .keyLabel)
        ) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid hotkey")
            )
        }
        self = hotkey
    }
}

/// Registers a system-wide hotkey through Carbon `RegisterEventHotKey`.
///
/// This needs no extra permission and consumes the key press, so the focused
/// app never receives it (nothing is typed into the field).
final class HotkeyMonitor {
    enum StartError: Error {
        /// Another app already registered the same shortcut.
        case alreadyInUse
        case failed(OSStatus)
    }

    private let hotkey: TranslationHotkey
    private let onHotkey: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(hotkey: TranslationHotkey, onHotkey: @escaping () -> Void) {
        self.hotkey = hotkey
        self.onHotkey = onHotkey
    }

    func start() throws {
        guard hotKeyRef == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else {
                    return OSStatus(eventNotHandledErr)
                }
                // Carbon delivers application-target events on the main thread.
                Unmanaged<HotkeyMonitor>.fromOpaque(userData).takeUnretainedValue().onHotkey()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )

        guard handlerStatus == noErr else {
            throw StartError.failed(handlerStatus)
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x534C_5348), id: 1) // "SLSH"
        let registerStatus = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            stop()
            throw registerStatus == OSStatus(eventHotKeyExistsErr)
                ? StartError.alreadyInUse
                : StartError.failed(registerStatus)
        }
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    deinit {
        stop()
    }
}
