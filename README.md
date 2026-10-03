# Slashlate

> **Translate what you type, right where you type.**

Slashlate is a tiny open-source macOS utility for inline translation. The
first release is intentionally focused: type in Spanish, finish with `///`,
and Slashlate will replace the current text with natural English without
making you leave the app you are using.

## Status

**M1.2** - real Spanish -> English translation via OpenRouter (M1), with
translation scopes (M1.1), visible status feedback and Electron app support
(M1.2). See [`CHANGELOG.md`](CHANGELOG.md) and the known limitations in
[`docs/M1_TEST_PLAN.md`](docs/M1_TEST_PLAN.md).

M0 (global `///` detection, Accessibility permission, reading and replacing
the focused field inline) has been validated on a real Mac.

M1 replaces the M0 test string with a real translation:

```text
ya terminé el cambio ///
↓
I've finished the change.
```

M1.1 adds a second trigger that translates only the current line:

| Trigger | Scope | Translates |
| --- | --- | --- |
| `///` | whole field | everything in the field (M1 behavior, unchanged) |
| `//.` | current line | only the line that contains the cursor |

```text
Esta línea debe permanecer en español.
esta linea debe traducirse //.
↓
Esta línea debe permanecer en español.
This line should be translated.
```

Or press **`⌃⌥T`** (Control-Option-T, configurable in Settings): Slashlate
translates the selected text, or the whole field if nothing is selected. Nothing is typed, so it
also works where `/` opens a command menu.

`//.` needs the field to report its cursor position through Accessibility
(`AXSelectedTextRange`). If a control does not, Slashlate leaves the text
untouched and says so in the menu-bar status - use `///` there.

The model is called through the [OpenRouter](https://openrouter.ai) HTTP API
(`openai/gpt-5-nano` by default, defined once in
`Sources/Slashlate/Translation/OpenRouterClient.swift`).

How a translation is applied safely:

1. when `///` or `//.` is typed, Slashlate captures the focused element, its
   value and (for `//.`) the cursor position;
2. the trigger is stripped only from the text sent to the model - the
   visible field is not touched while waiting;
3. when the translation arrives, Slashlate re-checks **the same element**:
   it must still be focused and still contain exactly the original text;
4. only then is the field written: the whole value for `///`, or only the
   current line for `//.` (everything before and after it is kept exactly).

If the request fails, times out, or you changed the text / field / app in the
meantime, your original text (including `///`) stays exactly as it was and
the reason is shown in the menu-bar popover. The same applies to `//.`.

The menu-bar icon shows `…` while translating and ⚠️ when the last attempt
failed or was discarded; click it to see why (red = error, orange =
discarded, green = translated).

## Requirements

- macOS 14 or newer
- Swift 5.10+ / Xcode Command Line Tools

## Build and run

```bash
git clone https://github.com/hector53/slashlate.git
cd slashlate
make run
```

This builds a release binary, assembles `build/Slashlate.app`, applies an
ad-hoc signature, and launches it.

To install it in `/Applications` (recommended if you enable "Open at
login"):

```bash
make install
```

Run the unit tests with:

```bash
make test
```

On first launch macOS should request Accessibility access. If necessary, open:

**System Settings -> Privacy & Security -> Accessibility**

and enable Slashlate. The menu-bar popover shows whether permission is active.

## Configure the OpenRouter API key

1. Create a key at <https://openrouter.ai/keys>.
2. Click the Slashlate icon in the menu bar, then **Settings…**.
3. In the **OpenRouter** tab, paste the key and click **Save API Key**.

The key is stored in your login **macOS Keychain** (item
"Slashlate OpenRouter API Key"). It is never written to `UserDefaults`, to
disk in plain text, to logs, or to the repository. Use **Replace API Key** to
change it.

## Settings

**Settings…** in the menu-bar popover opens:

- **General** - open Slashlate at login. macOS registers the app at its
  current path, so enable it from the copy installed with `make install`
  (not from `build/`). If you move or delete the app, turn the option off
  and on again.
- **Hotkey** - click the shortcut and press a new one (must include ⌃ or ⌥;
  Esc cancels), or reset to `⌃⌥T`.
- **OpenRouter** - API key (stored only in the Keychain).

### Keeping permissions across rebuilds

By default the app is ad-hoc signed. macOS identifies ad-hoc apps by their
binary hash, so **every rebuild looks like a new app**: the Accessibility
toggle stays on in System Settings but no longer applies, and Keychain asks
for access again.

To avoid this, sign with a stable identity (any "Apple Development"
certificate works):

```bash
security find-identity -v -p codesigning   # pick an identity
export SLASHLATE_SIGN_IDENTITY="Apple Development: you@example.com (TEAMID)"
make run
```

Shells that do not load `~/.zshrc` (IDE terminals, tools, scripts) will not
see that variable and silently fall back to ad-hoc. To avoid that, also put
the identity in an untracked file at the repo root (it is in `.gitignore`):

```bash
echo "<identity hash>" > .signing-identity
```

`make app` prints a warning whenever it falls back to an ad-hoc signature.
Check the current build with `codesign -dvv build/Slashlate.app` (it must
show `Authority=Apple Development: ...`, not `Signature=adhoc`).

If permission already looks granted but Slashlate says it is required, reset
the stale entry and grant it again:

```bash
tccutil reset Accessibility dev.hectoracosta.slashlate
```

## Smoke test

Open TextEdit or a browser text field and type:

```text
hola mundo ///
```

After roughly a second the field becomes something like:

```text
Hello world.
```

And for a single line, with the cursor at the end of the middle line:

```text
linea 1
hola mundo //.
linea 3
```

becomes:

```text
linea 1
Hello world.
linea 3
```

Slashlate must **never** submit or send the text automatically.

Manual test cases live in [`docs/M1_TEST_PLAN.md`](docs/M1_TEST_PLAN.md)
(including the M1.1 `//.` cases);
M0 compatibility notes are in [`docs/M0_TEST_PLAN.md`](docs/M0_TEST_PLAN.md).

## Project structure

```text
Sources/Slashlate/
├── Accessibility/
│   └── AccessibilityService.swift
├── Keyboard/
│   ├── HotkeyMonitor.swift        # global ⌃⌥T (TranslationHotkey)
│   ├── KeyboardMonitor.swift
│   └── TriggerDetector.swift      # which trigger was typed
├── Security/
│   └── KeychainService.swift
├── Settings/
│   ├── SettingsStore.swift        # hotkey in UserDefaults
│   └── LaunchAtLogin.swift        # SMAppService
├── Translation/
│   ├── TranslationService.swift   # provider boundary
│   ├── OpenRouterClient.swift     # OpenRouter implementation + config
│   ├── OpenRouterModels.swift
│   ├── TranslationPrompt.swift
│   ├── TranslationTrigger.swift   # triggers and their TranslationScope
│   └── TranslationTarget.swift    # what to translate/replace + safety check
├── UI/
│   ├── MenuBarView.swift          # popover
│   ├── SettingsView.swift         # Settings window
│   └── HotkeyRecorder.swift
├── AppState.swift
└── SlashlateApp.swift

Resources/
└── Info.plist

Tests/SlashlateTests/

scripts/
├── build-app.sh
└── run-app.sh
```

## Design principles

- Never send a message automatically.
- Never replace text unless the focused field still contains exactly the
  text it had when the trigger was typed.
- Never commit user secrets.
- Keep the core interaction fast and invisible.
- Prefer a small native macOS implementation over a large cross-platform stack.

## Roadmap

### M0 - macOS inline replacement (validated)
- global `///` detection
- Accessibility permission
- focused-field read/write
- real-app compatibility testing

### M1 - translation
- Spanish -> English
- OpenRouter
- fast, inexpensive model
- natural professional tone
- safe failure behavior that preserves the original text

### M1.1 - translation scopes
- `///` translates the whole field
- `//.` translates only the current line

### M1.2 - status feedback and Electron apps (current)
- menu-bar icon and colored status for errors / discarded translations
- Slack and other Electron apps via `AXManualAccessibility`

### M2 - product shell (v0.2.0)
- global hotkey `⌃⌥T` (selection or whole field) - done
- configurable hotkey - done
- settings window - done
- launch at login - done
- configurable typed triggers - deferred (URL / code collisions)
- lightweight settings

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).

## License

[MIT](LICENSE)
