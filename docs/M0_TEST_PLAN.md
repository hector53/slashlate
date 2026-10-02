# M0 test plan

M0 validates the macOS interaction layer before any translation API is added.

## Expected behavior

With Slashlate running and Accessibility permission granted:

1. focus a writable text field;
2. type `hola mundo ///`;
3. after the third slash, the field should become `TEST TRANSLATION`;
4. Slashlate must not submit, send, or press Enter.

## Suggested order

| Application / control | Result | Notes |
| --- | --- | --- |
| TextEdit plain text | Not tested | Baseline native macOS control |
| Safari textarea | Not tested | Browser baseline |
| Chrome textarea | Not tested | Chromium baseline |
| ChatGPT composer | Not tested | Web editor |
| Slack composer | Not tested | Electron / rich text |
| VS Code editor | Not tested | Expected to be treated cautiously |

## Failure information to capture

If a field does not work, record:

- application and version;
- whether `///` was detected (check menu-bar status);
- Slashlate status/error text;
- whether the field still contains the original text;
- whether a native textarea in the same app works.

Do not add translation API work until the baseline native field and at least
one browser field work reliably.
