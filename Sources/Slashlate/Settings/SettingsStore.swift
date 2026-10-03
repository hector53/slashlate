import Foundation

/// Non-secret preferences in `UserDefaults`. The API key is never stored
/// here; it lives only in the Keychain.
struct SettingsStore {
    private let defaults: UserDefaults
    private let hotkeyKey = "hotkey"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The saved hotkey, or the default if none (or an invalid one) is stored.
    var hotkey: TranslationHotkey {
        get {
            guard let data = defaults.data(forKey: hotkeyKey),
                  let hotkey = try? JSONDecoder().decode(TranslationHotkey.self, from: data)
            else {
                return .translate
            }
            return hotkey
        }
        nonmutating set {
            if newValue == .translate {
                defaults.removeObject(forKey: hotkeyKey)
            } else if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: hotkeyKey)
            }
        }
    }
}
