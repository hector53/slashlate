# Slashlate

> **Translate what you type, right where you type.**

Slashlate is a tiny open-source macOS utility for inline translation. The
first release is intentionally focused: type in Spanish, finish with `///`,
and Slashlate will replace the current text with natural English without
making you leave the app you are using.

## Status

**M0 - inline replacement prototype**

M0 deliberately does not call OpenRouter or any translation API yet. It
validates the hardest part of the product first:

1. detect the global `///` trigger;
2. read the currently focused text field through macOS Accessibility;
3. verify that the field really ends in `///`;
4. replace its contents inline.

For M0, the replacement is the literal text:

```text
TEST TRANSLATION
```

If that works reliably on a real Mac, M1 will replace the test value with an
OpenRouter translation.

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

On first launch macOS should request Accessibility access. If necessary, open:

**System Settings -> Privacy & Security -> Accessibility**

and enable Slashlate. The menu-bar popover shows whether permission is active.

## M0 smoke test

Open TextEdit or a browser text field and type:

```text
hola mundo ///
```

Expected result:

```text
TEST TRANSLATION
```

Slashlate must **never** submit or send the text automatically.

Compatibility findings belong in
[`docs/M0_TEST_PLAN.md`](docs/M0_TEST_PLAN.md).

## Project structure

```text
Sources/Slashlate/
├── Accessibility/
│   └── AccessibilityService.swift
├── Keyboard/
│   ├── KeyboardMonitor.swift
│   └── TriggerDetector.swift
├── UI/
│   └── MenuBarView.swift
├── AppState.swift
└── SlashlateApp.swift

Resources/
└── Info.plist

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

### M0 - macOS inline replacement
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

### M2 - product shell
- configurable trigger
- configurable hotkey
- API key in macOS Keychain
- launch at login
- lightweight settings

## License

[MIT](LICENSE)
