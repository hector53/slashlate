# M1 / M1.1 test plan

M1 adds real Spanish -> English translation through OpenRouter. These checks
must be done manually on a real Mac with Accessibility granted and an
OpenRouter API key saved from the menu-bar popover.

Keep the Slashlate popover status in mind: it shows `Translating...`,
`Translated`, or the reason a translation was not applied.

## Core cases

| # | Scenario | Steps | Expected | Result |
| --- | --- | --- | --- | --- |
| 1 | TextEdit | Type `hola mundo ///` | Becomes natural English (e.g. `Hello world.`) in ~1-2 s. Nothing is sent. | tested |
| 2 | Browser textarea (Safari / Chrome) | Type `ya terminé el cambio y lo subí a staging ///` | `I've finished the change and deployed it to staging.` (or similar) | tested |
| 3 | ChatGPT composer | Type `listo ya subi el fix, puedes probarlo cuando puedas ///` | Translated in place; message is **not** submitted | tested |
| 4 | Mixed English/Spanish | `Hey Paul, ya revise el problema y creo que viene del backend ///` | `Hey Paul, I've looked into the issue...`; names and English kept | tested |
| 5 | Technical content | `revisa JIRA-142, el endpoint /api/v1/users falla con npm run dev ///` | IDs, paths, commands preserved verbatim | tested |
| 6 | Multi-line | Two paragraphs then `///` | Paragraph break preserved | tested |

## Failure safety

| # | Scenario | Steps | Expected | Result |
| --- | --- | --- | --- | --- |
| 7 | No API key | Remove the Keychain item, type `hola ///` | Text unchanged; status `OpenRouter API key is not configured` | tested |
| 8 | Invalid API key | Save `sk-or-invalid`, type `hola mundo ///` | `hola mundo ///` unchanged; status `OpenRouter authentication failed...` | tested, no hace nada, no traduce pero tampoco muestra ningun error. |
| 9 | No internet | Turn Wi-Fi off, type `hola mundo ///` | Text unchanged; status `Network unavailable...` | tested, igual que el anterior no sale mensaje de error |
| 10 | Edit while waiting | Type `hola mundo ///` and immediately type more characters | Field keeps what you typed; status `Translation discarded - the text changed...` | tested, no muestra ningun mensaje tampoco, ademas luego de escribir /// y luego texto rapido seguido, hace que no funcione la traduccion. |
| 11 | Delete while waiting | Type `hola mundo ///` and immediately delete a word | Field keeps your edit; translation discarded | tested |
| 12 | Switch field | Type `hola mundo ///`, immediately click another text field | Neither field is replaced; status `...focus moved to another field` | tested, al mover el focus no ocurre traduccion, supongo es lo esperado |
| 13 | Switch app | Type `hola mundo ///`, immediately Cmd-Tab to another app | No field in either app is replaced | tested, igual q la de arriba, al moverme a otro tab no traduce |
| 14 | Double trigger | Type `hola /// ///` quickly | Only one request; second trigger ignored; original edited text is not overwritten | tested, esto hizo que no ocurriera la traduccion|
| 15 | Trigger only | Type `///` in an empty field | Nothing replaced; status `Nothing to translate` | tested, no pasa nada , no deja ningun mensaje |

Tip for 10-13: with a fast model the window is short. Turning on a slow
network (Network Link Conditioner) or typing immediately after the third `/`
makes it easier to reproduce.

## Keychain

| # | Scenario | Expected | Result |
| --- | --- | --- | --- |
| 16 | Save key | Popover shows `✓ Configured`; Keychain Access contains "Slashlate OpenRouter API Key" | tested |
| 17 | Relaunch app | Still shows `Configured`, translation works |  tested |
| 18 | Rebuild (`make run`) | macOS may prompt for Keychain access - `Always Allow`; translation works | tested |
| 19 | Replace key | `Replace API Key` -> save new key -> translation uses new key |  tested |

## M1.1 - current line

`//.` translates only the line that contains the cursor. `///` must keep
working exactly as before (re-run cases 1, 6 and 10).

| # | Scenario | Steps | Expected | Result |
| --- | --- | --- | --- | --- |
| 20 | Last line (TextEdit) | `Esta línea debe permanecer en español.` ⏎ `esta linea debe traducirse //.` | Only line 2 becomes English; line 1 identical | tested |
| 21 | Middle line | Type 3 lines, click at end of line 2, type ` //.` | Only line 2 translated; lines 1 and 3 identical; cursor at end of line 2 | tested |
| 22 | Empty lines around | Blank lines above/below the target line | Blank lines preserved |  tested |
| 23 | Indented line | `    hola mundo //.` | Indentation kept, text translated |  tested |
| 24 | `///` regression | Two lines then `///` | Whole field translated as in M1 | tested |
| 25 | URL | Type `mira https://example.com` | Nothing triggers | tested |
| 26 | Edit another line while waiting | Type `//.` on line 2, immediately edit line 1 | Translation discarded, edits kept | tested, hice dos lineas , en la segunda puse "//." y me fui arriba a la primera linea y no hice nada y funciono, pero volvi a hacer la prueba y cuando subi escribi rapido y ahi sino hizo la traduccion. |
| 27 | Switch field / app while waiting | `//.` then click another field or Cmd-Tab | Nothing replaced anywhere | tested, si doy clic a otra app o lo que sea que me mueva el focus no traduce. |
| 28 | Browser textarea | Cases 20-21 in Safari / Chrome | Same as TextEdit, or safe failure | tested |
| 29 | Electron / web editor without cursor | `//.` in Slack / ChatGPT | Translated, or status `This field does not report the cursor position...` with text untouched | **Re-tested after Electron fix: works in Slack.** Original note: en slack no funciona la traduccion de ningun tipo, como que no reconoce los "///", en la pagina web de chatgpt si funciona, pero no probe en la app de mac de chatgpt. |
| 30 | API failure | Wi-Fi off, `hola //.` | `hola //.` untouched, error in status |  tested, esta pruyeba es igual a una de las de arriba. |

## Findings from the first full pass (2026-10-02)

- **8, 9, 10, 15 - "no error message":** the message was produced but shown
  only as small gray text inside the popover; the menu-bar icon never
  changed. Fixed: the icon now shows ⚠️ until the popover is opened, and the
  status line is colored by kind. Re-test.
- **10, 14, 26 - typing right after the trigger cancels the translation:**
  by design. The field no longer matches the captured snapshot, so the
  translation is discarded to avoid overwriting what was just typed (status
  `Translation discarded - the text changed while translating`).
- **12, 13, 27 - switching field/app cancels the translation:** by design.
- **29 - Slack:** no trigger works. Status: `Could not read the focused
  text field (AX -25212)`. -25212 is `kAXErrorNoValue`: the system-wide
  focused-element query returns nothing because Slack (Electron) does not
  build its accessibility tree by default. The keyboard trigger is detected
  and the failure is safe (text untouched). **Fixed:** when the system-wide
  query fails, Slashlate sets `AXManualAccessibility = true` on the frontmost
  app's `AXUIElement` and reads its focused element. Validated in Slack. ChatGPT web works; ChatGPT macOS app not
  tested.
- **Status feedback fix** (⚠️ icon + colored status) validated on a real Mac.

## Known limitations (M1.2)

| App | Status | Result |
| --- | --- | --- |
| ChatGPT macOS app (Electron) | `Could not read the focused text field (AX -25212)` | Not supported yet. Likely the `/` command menu takes focus. Text untouched. ChatGPT web works. |
| Copilot chat in VS Code (Monaco) | `Trigger detected, but the focused field changed` | Not supported. Monaco exposes only part of its text unless `editor.accessibilitySupport` is `on` (not tested). Codex chat in VS Code works. |
| Terminals (Claude Code CLI) | - | Not supported: no editable Accessibility text field. |

## What to record on failure

- application and version;
- Slashlate status text;
- whether the field still contains the original text with `///`;
- whether the same app works with M0-style native fields.
