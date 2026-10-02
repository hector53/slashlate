# Slashlate

> **Translate what you type, right where you type.**

Slashlate is a tiny open-source macOS utility for inline translation. The
first release is intentionally focused: type in Spanish, finish with `///`,
and Slashlate will replace the current text with natural English without
making you leave the app you are using.

## Status

**M1 - real Spanish -> English translation via OpenRouter**

M0 (global `///` detection, Accessibility permission, reading and replacing
the focused field inline) has been validated on a real Mac.

M1 replaces the M0 test string with a real translation:

```text
ya terminé el cambio ///
↓
I've finished the change.
```

The model is called through the [OpenRouter](https://openrouter.ai) HTTP API
(`openai/gpt-5-nano` by default, defined once in
`Sources/Slashlate/Translation/OpenRouterClient.swift`).

How a translation is applied safely:

1. when `///` is typed, Slashlate captures the focused element and its value;
2. the trigger is stripped only from the text sent to the model - the
   visible field is not touched while waiting;
3. when the translation arrives, Slashlate re-checks **the same element**:
   it must still be focused and still contain exactly the original text;
4. only then is the field replaced.

If the request fails, times out, or you changed the text / field / app in the
meantime, your original text (including `///`) stays exactly as it was and
the reason is shown in the menu-bar popover.

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

Run the unit tests with:

```bash
make test
```

On first launch macOS should request Accessibility access. If necessary, open:

**System Settings -> Privacy & Security -> Accessibility**

and enable Slashlate. The menu-bar popover shows whether permission is active.

## Configure the OpenRouter API key

1. Create a key at <https://openrouter.ai/keys>.
2. Click the Slashlate icon in the menu bar.
3. Paste the key into **OpenRouter API Key** and click **Save API Key**.

The key is stored in your login **macOS Keychain** (item
"Slashlate OpenRouter API Key"). It is never written to `UserDefaults`, to
disk in plain text, to logs, or to the repository. Use **Replace API Key** to
change it.

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

Slashlate must **never** submit or send the text automatically.

Manual test cases live in [`docs/M1_TEST_PLAN.md`](docs/M1_TEST_PLAN.md);
M0 compatibility notes are in [`docs/M0_TEST_PLAN.md`](docs/M0_TEST_PLAN.md).

## Project structure

```text
Sources/Slashlate/
├── Accessibility/
│   └── AccessibilityService.swift
├── Keyboard/
│   ├── KeyboardMonitor.swift
│   └── TriggerDetector.swift
├── Security/
│   └── KeychainService.swift
├── Translation/
│   ├── TranslationService.swift   # provider boundary
│   ├── OpenRouterClient.swift     # OpenRouter implementation + config
│   ├── OpenRouterModels.swift
│   ├── TranslationPrompt.swift
│   └── TriggeredText.swift        # trigger stripping + replace safety check
├── UI/
│   └── MenuBarView.swift
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
- Never replace text unless the focused field still contains the trigger.
- Never commit user secrets.
- Keep the core interaction fast and invisible.
- Prefer a small native macOS implementation over a large cross-platform stack.

## Roadmap

### M0 - macOS inline replacement (validated)
- global `///` detection
- Accessibility permission
- focused-field read/write
- real-app compatibility testing

### M1 - translation (current)
- Spanish -> English
- OpenRouter
- fast, inexpensive model
- natural professional tone
- safe failure behavior that preserves the original text

### M2 - product shell
- configurable trigger
- configurable hotkey
- full settings window (M1 ships only a minimal API key field)
- launch at login
- lightweight settings

## License

[MIT](LICENSE)
