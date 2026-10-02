# Changelog

All notable changes to Slashlate are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Entries are grouped by milestone; there are no tagged releases yet.

## [Unreleased]

### Added
- Menu-bar icon reflects state: `…` while translating, ⚠️ when the last
  attempt failed or was discarded and has not been seen yet (cleared when
  the popover opens or closes).
- Popover status line shows an icon and color by kind: green (translated),
  orange (discarded / nothing to translate), red (API, network or
  Accessibility error).
- Electron apps (Slack, Discord, ...): when the system-wide focused-element
  query fails, Slashlate sets `AXManualAccessibility` on the frontmost app
  and reads its focused element directly. Native apps are unaffected.
  Validated in Slack on a real Mac (manual test 29).

### Fixed
- Slack: no trigger worked (`AX -25212`, `kAXErrorNoValue`) because Electron
  did not expose a focused element. Fixed by the fallback above.
- Errors and discarded translations were effectively invisible: the status
  was small gray text only inside the popover (manual tests 8, 9, 10, 15).

### Pending
- ChatGPT macOS app not tested yet.

## [M1.1] - 2026-10-02 - Translation scopes

### Added
- `//.` trigger: translates only the line that contains the cursor. Text
  before and after the line is kept byte-for-byte; line indentation is kept.
- `TranslationScope` (`wholeField`, `currentLine`) and `TranslationTrigger`,
  the single place where triggers and their scopes are defined.
- Cursor position read through `AXSelectedTextRange`. If a control does not
  expose it, `//.` fails safely and leaves the text untouched.
- After a `//.` replacement, the cursor is placed at the end of the
  translated line (best effort).
- `.signing-identity` (gitignored) as a fallback for
  `SLASHLATE_SIGN_IDENTITY`, plus a warning when a build is signed ad-hoc.
- Unit tests for current-line targets and trigger detection (48 total).

### Changed
- `TriggeredText` replaced by `TranslationTarget` (scope, original value,
  source text, replacement range). Both scopes share one
  capture -> target -> translate -> validate -> replace flow.
- `TriggerDetector` reports which trigger fired.
- Menu-bar help text lists both triggers.

### Fixed
- Accessibility showing as "required" after a build made from a shell that
  does not load `~/.zshrc` (silent ad-hoc signature).

### Unchanged
- `///` still translates the whole field exactly as in M1.

## [M1] - 2026-10-02 - Real translation

### Added
- Spanish -> English translation through the OpenRouter HTTP API
  (`openai/gpt-5-nano`, defined once in `OpenRouterConfiguration`), behind
  the `TranslationService` protocol.
- OpenRouter API key stored in the macOS Keychain, read once per launch;
  minimal API key field in the menu-bar popover.
- Async safety: the original text is replaced only if the same element is
  still focused and still contains exactly the captured value. Any error
  leaves the original text (including `///`) untouched.
- At most one translation in flight; ~10 s timeout.
- `make test` and unit tests for the OpenRouter client and trigger handling.
- Optional stable code signing with `SLASHLATE_SIGN_IDENTITY` so rebuilds
  keep Accessibility and Keychain access.

## [M0] - 2026-10-02 - Inline replacement

### Added
- Menu-bar app with global `///` detection.
- Accessibility permission flow.
- Reading and replacing the focused text field inline with a test string.

### Fixed
- Dynamic status text in the menu.
- Clearer Accessibility error messages.
- Menu shows the configured trigger.
