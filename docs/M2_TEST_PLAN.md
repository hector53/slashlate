# M2 test plan - hotkey

`⌃⌥T` translates the selection, or the whole field if nothing is selected.
Run on a real Mac with Accessibility granted and an API key saved.

| # | Scenario | Steps | Expected | Result |
| --- | --- | --- | --- | --- |
| 1 | Whole field (TextEdit) | Type `hola mundo`, press `⌃⌥T` | `Hello world.`; no `t` typed | tested |
| 2 | Selection in a line | `Ok, mañana lo reviso, thanks`, select `mañana lo reviso`, `⌃⌥T` | Only the selection translated | Not tested |
| 3 | Selection across lines | Select line 2 of 3 (including its line break) | Only line 2 translated; line breaks kept | Not tested |
| 4 | Multi-line field, no selection | 2 paragraphs, cursor anywhere, `⌃⌥T` | Whole field translated | Not tested |
| 5 | Browser textarea | Cases 1-2 in Safari / Chrome | Same as TextEdit | Not tested |
| 6 | Slack | Cases 1-2 | Same as TextEdit; message not sent | Not tested |
| 7 | ChatGPT macOS app | Case 1 (no `/` typed) | Translated, or safe failure with status | tested - works after the `AXEnhancedUserInterface` fallback |
| 8 | Edit while waiting | `⌃⌥T`, immediately type | Discarded, edits kept, ⚠️ | Not tested |
| 9 | Empty field | `⌃⌥T` | `Nothing to translate`, ⚠️ | Not tested |
| 10 | Disabled | Uncheck `Enabled`, `⌃⌥T` | Nothing happens | Not tested |
| 11 | Shortcut taken | Another app owns `⌃⌥T`, relaunch Slashlate | Warning in status; `///` still works | Not tested |
| 12 | Regressions | `///` and `//.` | Work as in M1.2 | Not tested |

## Findings (2026-10-03)

- Hotkey works in native fields, browsers and Slack.
- **ChatGPT macOS app:** first `AX -25212` with the hotkey too, so the `/`
  command menu was not the cause. Diagnostics log showed
  `AXManualAccessibility` rejected (AX -25205) and `AXEnhancedUserInterface`
  readable. After setting `AXEnhancedUserInterface` (reported AX -25208 but
  Chromium enabled its tree anyway) and retrying, it works.
- **Copilot chat in VS Code:** `Nothing to translate`. Monaco's hidden text
  area is empty outside screen-reader mode. Known limitation.
