import Carbon.HIToolbox

/// A global keyboard shortcut. The default is defined once, here.
struct TranslationHotkey: Equatable {
    /// Carbon virtual key code (physical key position, layout independent).
    let keyCode: UInt32
    /// Carbon modifier mask (`controlKey`, `optionKey`, ...).
    let modifiers: UInt32
    /// How the shortcut is shown in the UI.
    let displayName: String

    static let translate = TranslationHotkey(
        keyCode: UInt32(kVK_ANSI_T),
        modifiers: UInt32(controlKey | optionKey),
        displayName: "⌃⌥T"
    )
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
