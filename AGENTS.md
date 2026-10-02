# AGENTS.md

## Product

Slashlate is a tiny native macOS utility that translates text inline, in the
field where the user is already typing.

The primary interaction for v0.1 is:

1. user types Spanish text;
2. user types `///`;
3. Slashlate translates Spanish to natural English;
4. Slashlate replaces the text in place;
5. Slashlate never presses Enter or sends the message.

## Current milestone: M0

M0 exists only to validate macOS integration. Do not add OpenRouter, model
selection, multiple languages, accounts, analytics, or a large settings UI.

M0 must prove:

- global `///` detection;
- Accessibility permission handling;
- reading the currently focused text field;
- replacing that field inline;
- no automatic send action.

The expected M0 replacement is the literal string `TEST TRANSLATION`.

## Technical direction

- Swift + SwiftUI.
- macOS 14+.
- Menu-bar app.
- Swift Package Manager for source/build management.
- A small build script assembles the executable into a macOS app bundle.
- No App Sandbox for M0 because Accessibility is core to the product.

## Invariants

- Never automatically send user text.
- Never silently destroy the original text when an operation fails.
- Do not introduce clipboard replacement as a fallback unless the previous
  clipboard contents are restored reliably.
- Do not commit API keys or other secrets.
- Keep product scope narrow; prefer one reliable workflow over many features.
- M1 translation code must remain behind a small TranslationService boundary.

## Commands

```bash
swift build
make app
make run
make clean
```

## M0 validation

Start with TextEdit, then test browser text areas and Electron apps. Record
compatibility findings in `docs/M0_TEST_PLAN.md`.

A macOS integration change is not considered validated merely because it
compiles. Accessibility behavior must be tested on a real Mac.
