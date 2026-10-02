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

## Current milestone: M1.1 (translation scopes)

M1 is validated on a real Mac. M1.1 adds a second trigger:

- `///` -> `TranslationScope.wholeField` (M1 behavior, must not change);
- `//.` -> `TranslationScope.currentLine`: translates only the line that
  contains the cursor.

M1.1 rules:

- triggers and their scopes are defined once, in `TranslationTrigger`;
  `TriggerDetector` returns which trigger fired;
- scope-specific logic lives only in `TranslationTarget` (what to send to the
  model, which range to replace, where to leave the cursor); the
  capture -> parse target -> translate -> validate snapshot -> replace flow in
  `AppState` is shared by every scope;
- `//.` reads `kAXSelectedTextRangeAttribute`; the trigger must be
  immediately before an empty selection. If the control does not expose the
  cursor, fail safely and leave the text untouched (no clipboard fallback);
- only the current line is replaced; text before and after it is written back
  byte-for-byte;
- snapshot validation is unchanged: same element, exact same full value.

Not in M1.1: more triggers, configurable triggers or hotkeys, more
languages, advanced settings, M2 work.

## M1

M0 (global `///` detection, Accessibility permission, reading and replacing
the focused field inline, menu-bar app) is validated on a real Mac. Do not
rewrite that layer without a concrete reason.

M1 replaces the M0 test string with a real Spanish -> English translation
through the OpenRouter HTTP API (`URLSession`, no SDK).

M1 rules:

- one model only, defined once in `OpenRouterConfiguration`;
- the provider stays behind the `TranslationService` protocol;
- the OpenRouter API key lives only in macOS Keychain;
- capture the focused AX element + value on trigger, do not touch the visible
  text while waiting, and replace only if that same element is still focused
  and still contains exactly the original text;
- on any error, leave the original text (including `///`) untouched and show
  the error only in the menu-bar status;
- at most one translation in flight;
- request timeout of about 10 seconds.

Not in M1: multiple languages, other (beyond `//.` in M1.1) or configurable triggers, configurable
hotkeys, model/provider selectors, streaming, history, analytics, accounts,
auto update, launch at login, clipboard fallback, onboarding, main window,
telemetry.

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
- Every user-visible change, fix or milestone gets an entry in `CHANGELOG.md`
  (under `[Unreleased]` until the milestone is closed).

## Commands

```bash
swift build
make test
make app
make run
make clean
```

## Validation

Start with TextEdit, then test browser text areas and Electron apps. Record
M0 compatibility findings in `docs/M0_TEST_PLAN.md` and M1/M1.1 results in
`docs/M1_TEST_PLAN.md`.

A macOS integration change is not considered validated merely because it
compiles. Accessibility behavior must be tested on a real Mac.
