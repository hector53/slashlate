# Slashlate

> Translate what you type, right where you type.

Slashlate is a tiny open-source macOS utility for inline translation. The first version is intentionally focused: type in Spanish, finish with `///`, and Slashlate replaces the current text with English without making you leave the app you are using.

## Status

Slashlate is currently in **M0 (inline replacement prototype)**.

M0 does **not** call any translation API yet. Its only job is to prove the hardest macOS interaction:

1. detect the global `///` trigger;
2. read the currently focused text field through macOS Accessibility;
3. verify that the field ends in `///`;
4. replace its contents inline.

For M0, the replacement text is simply:

```text
TEST TRANSLATION
```

Once this works reliably across real apps, OpenRouter translation will be added in M1.

## Principles

- Never send a message automatically.
- Never lose the user's original text on an API failure.
- Keep the core interaction fast and invisible.
- Store secrets in macOS Keychain, never in the repository.
- Prefer a small native macOS implementation over a large cross-platform stack.

## Planned v0.1

- Spanish -> English
- `///` trigger
- configurable hotkey
- OpenRouter provider
- natural professional English
- menu-bar app
- API key stored in Keychain
- MIT licensed

## Development

Slashlate is written in Swift/SwiftUI and targets macOS.

Detailed local build instructions are added with the M0 source bootstrap.

## License

MIT
