# Changelog

All notable changes to Slashlate are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Entries are grouped by milestone; there are no tagged releases yet.

## [Unreleased]

## [M2] - 2026-10-03 - Hotkey and settings (v0.2.0)

### Added
- Settings window (`Settings…` in the popover) with three tabs:
  - **General:** open Slashlate at login (`SMAppService.mainApp`; the system
    is the source of truth, including "requires approval").
  - **Hotkey:** record a new translate shortcut (Esc cancels) or reset to
    `⌃⌥T`. Saved in `UserDefaults`. Shortcuts must use ⌃ or ⌥ so they never
    hijack app shortcuts like ⌘C. If the new shortcut cannot be registered,
    the previous one is restored. The hotkey is paused while recording.
  - **OpenRouter:** API key (moved from the popover; still Keychain only).
- `make install`: builds and copies the app to `/Applications` (override
  with `INSTALL_DIR`), so launch at login does not depend on `build/`.
- Global hotkey `⌃⌥T` (fixed, defined once in `TranslationHotkey`):
  translates the selected text, or the whole field if nothing is selected.
  Registered with Carbon `RegisterEventHotKey`; the key press is consumed
  and nothing is typed into the field.
- `TranslationScope.selection` and `TranslationRequest` (`typed` / `hotkey`).
  `TranslationTarget` still owns every scope decision; the hotkey reuses the
  same capture -> target -> translate -> validate -> replace flow.
- If `⌃⌥T` is taken by another app, a warning is shown and typed triggers
  keep working.
- Electron fallback also tries `AXEnhancedUserInterface` when an app rejects
  `AXManualAccessibility`, and always waits briefly the first time for the
  tree to be built (Chromium may enable it even when the call reports an
  error).
- Privacy-safe diagnostics via `os.Logger` (AX error codes and bundle IDs
  only, never field text):
  `/usr/bin/log stream --predicate 'subsystem == "dev.hectoracosta.slashlate"'`.

### Changed
- Popover shows only whether the API key is configured, plus `Settings…`.
- `Settings…` closes the popover and opens the Settings window centered and
  in front (it used to open behind the popover, partly hidden).
- Help text shows the current hotkey.
- App version is `0.2.0` (`CFBundleShortVersionString`); the popover shows
  it instead of a hard-coded milestone label.

### Fixed
- ChatGPT macOS app (`com.openai.codex`): rejected `AXManualAccessibility`
  (AX -25205) so no focused element was found (AX -25212). Now works with
  the hotkey after the `AXEnhancedUserInterface` fallback.

### Known limitations
- GitHub Copilot chat in VS Code: `Nothing to translate` with the hotkey.
  Monaco leaves its accessibility text area empty unless VS Code runs in
  screen-reader mode (`editor.accessibilitySupport: on`, not adopted).
- `AXEnhancedUserInterface` can make window animations or window managers
  (Rectangle, Magnet) behave differently in the app it is set on, until that
  app quits. Only set for apps that reject `AXManualAccessibility`.

## [M1.2] - 2026-10-02 - Visible status and Electron support

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

### Known limitations
- ChatGPT macOS app (`com.openai.codex`, Electron-based): `AX -25212`, no
  focused element even with the Electron fallback. Suspected cause: typing
  `/` opens ChatGPT's command menu, which takes focus. Text is left
  untouched. ChatGPT in the browser works.
- GitHub Copilot chat in VS Code (Monaco editor): `Trigger detected, but the
  focused field changed`; Monaco only exposes part of its text to
  Accessibility unless VS Code's `editor.accessibilitySupport` is `on`.
  The Codex chat in VS Code works.
- Terminals (e.g. Claude Code CLI) have no editable text field to read or
  replace through Accessibility; not supported.

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
