# M1 / M1.1 test plan

M1 adds real Spanish -> English translation through OpenRouter. These checks
must be done manually on a real Mac with Accessibility granted and an
OpenRouter API key saved from the menu-bar popover.

Keep the Slashlate popover status in mind: it shows `Translating...`,
`Translated`, or the reason a translation was not applied.

## Core cases

| # | Scenario | Steps | Expected | Result |
| --- | --- | --- | --- | --- |
| 1 | TextEdit | Type `hola mundo ///` | Becomes natural English (e.g. `Hello world.`) in ~1-2 s. Nothing is sent. | Not tested |
| 2 | Browser textarea (Safari / Chrome) | Type `ya terminé el cambio y lo subí a staging ///` | `I've finished the change and deployed it to staging.` (or similar) | Not tested |
| 3 | ChatGPT composer | Type `listo ya subi el fix, puedes probarlo cuando puedas ///` | Translated in place; message is **not** submitted | Not tested |
| 4 | Mixed English/Spanish | `Hey Paul, ya revise el problema y creo que viene del backend ///` | `Hey Paul, I've looked into the issue...`; names and English kept | Not tested |
| 5 | Technical content | `revisa JIRA-142, el endpoint /api/v1/users falla con npm run dev ///` | IDs, paths, commands preserved verbatim | Not tested |
| 6 | Multi-line | Two paragraphs then `///` | Paragraph break preserved | Not tested |

## Failure safety

| # | Scenario | Steps | Expected | Result |
| --- | --- | --- | --- | --- |
| 7 | No API key | Remove the Keychain item, type `hola ///` | Text unchanged; status `OpenRouter API key is not configured` | Not tested |
| 8 | Invalid API key | Save `sk-or-invalid`, type `hola mundo ///` | `hola mundo ///` unchanged; status `OpenRouter authentication failed...` | Not tested |
| 9 | No internet | Turn Wi-Fi off, type `hola mundo ///` | Text unchanged; status `Network unavailable...` | Not tested |
| 10 | Edit while waiting | Type `hola mundo ///` and immediately type more characters | Field keeps what you typed; status `Translation discarded - the text changed...` | Not tested |
| 11 | Delete while waiting | Type `hola mundo ///` and immediately delete a word | Field keeps your edit; translation discarded | Not tested |
| 12 | Switch field | Type `hola mundo ///`, immediately click another text field | Neither field is replaced; status `...focus moved to another field` | Not tested |
| 13 | Switch app | Type `hola mundo ///`, immediately Cmd-Tab to another app | No field in either app is replaced | Not tested |
| 14 | Double trigger | Type `hola /// ///` quickly | Only one request; second trigger ignored; original edited text is not overwritten | Not tested |
| 15 | Trigger only | Type `///` in an empty field | Nothing replaced; status `Nothing to translate` | Not tested |

Tip for 10-13: with a fast model the window is short. Turning on a slow
network (Network Link Conditioner) or typing immediately after the third `/`
makes it easier to reproduce.

## Keychain

| # | Scenario | Expected | Result |
| --- | --- | --- | --- |
| 16 | Save key | Popover shows `✓ Configured`; Keychain Access contains "Slashlate OpenRouter API Key" | Not tested |
| 17 | Relaunch app | Still shows `Configured`, translation works | Not tested |
| 18 | Rebuild (`make run`) | macOS may prompt for Keychain access - `Always Allow`; translation works | Not tested |
| 19 | Replace key | `Replace API Key` -> save new key -> translation uses new key | Not tested |

## M1.1 - current line

`//.` translates only the line that contains the cursor. `///` must keep
working exactly as before (re-run cases 1, 6 and 10).

| # | Scenario | Steps | Expected | Result |
| --- | --- | --- | --- | --- |
| 20 | Last line (TextEdit) | `Esta línea debe permanecer en español.` ⏎ `esta linea debe traducirse //.` | Only line 2 becomes English; line 1 identical | Not tested |
| 21 | Middle line | Type 3 lines, click at end of line 2, type ` //.` | Only line 2 translated; lines 1 and 3 identical; cursor at end of line 2 | Not tested |
| 22 | Empty lines around | Blank lines above/below the target line | Blank lines preserved | Not tested |
| 23 | Indented line | `    hola mundo //.` | Indentation kept, text translated | Not tested |
| 24 | `///` regression | Two lines then `///` | Whole field translated as in M1 | Not tested |
| 25 | URL | Type `mira https://example.com` | Nothing triggers | Not tested |
| 26 | Edit another line while waiting | Type `//.` on line 2, immediately edit line 1 | Translation discarded, edits kept | Not tested |
| 27 | Switch field / app while waiting | `//.` then click another field or Cmd-Tab | Nothing replaced anywhere | Not tested |
| 28 | Browser textarea | Cases 20-21 in Safari / Chrome | Same as TextEdit, or safe failure | Not tested |
| 29 | Electron / web editor without cursor | `//.` in Slack / ChatGPT | Translated, or status `This field does not report the cursor position...` with text untouched | Not tested |
| 30 | API failure | Wi-Fi off, `hola //.` | `hola //.` untouched, error in status | Not tested |

## What to record on failure

- application and version;
- Slashlate status text;
- whether the field still contains the original text with `///`;
- whether the same app works with M0-style native fields.
