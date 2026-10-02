# M1 - Implementación

Registro de lo implementado en M1 (traducción real español → inglés con
OpenRouter) y de los problemas de firma/permisos encontrados al probarlo en un
Mac real. El plan original está en [`M1_plan.md`](M1_plan.md) y las pruebas
manuales en [`M1_TEST_PLAN.md`](M1_TEST_PLAN.md).

## Estado

- `hola mundo ///` → traducción real al inglés, en el mismo campo. **Validado
  en Mac real.**
- `swift build`, `make test` (23 tests) y `make app` funcionan sin warnings.
- Pendiente: completar `M1_TEST_PLAN.md` (browser, ChatGPT, fallos de red,
  cambio de campo/app).

## Flujo de traducción

```text
usuario escribe "texto ///"
        │
        ▼
KeyboardMonitor detecta ///                     (sin cambios desde M0)
        │
        ▼
AccessibilityService.captureFocusedTextField()
  - AXUIElement enfocado + su valor actual
  - verifica que el valor es texto y es escribible
        │
        ▼
TriggeredText(fieldValue:trigger:)
  - originalValue = "texto ///"   (lo que debe seguir habiendo en el campo)
  - sourceText    = "texto"       (lo que se envía al modelo)
        │
        ▼
status = "Translating..."   ← el campo visible NO se toca
        │
        ▼
TranslationService.translate(sourceText)        (async, OpenRouter)
        │
        ▼
AccessibilityService.replaceText(in:expectedValue:with:)
  - ¿el MISMO elemento sigue enfocado?          (CFEqual)
  - ¿su valor sigue siendo exactamente originalValue?
  - solo entonces escribe la traducción
        │
        ▼
status = "Translated" | "Translation discarded - ..." | mensaje de error
```

Garantías:

- Si la API falla, hay timeout, o el usuario cambió el texto, el campo o la
  app mientras esperaba, el texto original (con `///`) queda intacto.
- Nunca se busca "el campo enfocado ahora" para escribir: se reutiliza la
  referencia capturada al detectar el trigger.
- Solo una traducción a la vez (`activeTranslation` en `AppState`). Un `///`
  durante una traducción en curso se ignora.
- Nunca se pulsa Enter ni se envía nada.

## Archivos

### Nuevos

| Archivo | Responsabilidad |
| --- | --- |
| `Sources/Slashlate/Translation/TranslationService.swift` | Protocolo `TranslationService` (frontera con el provider) y `TranslationError` con mensajes legibles |
| `Sources/Slashlate/Translation/OpenRouterClient.swift` | `OpenRouterConfiguration` (modelo, endpoint, timeout: único lugar a cambiar) y `OpenRouterTranslationService` |
| `Sources/Slashlate/Translation/OpenRouterModels.swift` | Solo el JSON necesario de request/response |
| `Sources/Slashlate/Translation/TranslationPrompt.swift` | System prompt |
| `Sources/Slashlate/Translation/TriggeredText.swift` | Lógica pura: quitar el trigger y decidir si se puede reemplazar (`ReplacementDecision`) |
| `Sources/Slashlate/Security/KeychainService.swift` | API key en el login Keychain + caché en memoria (`CachedKeychainValue`) |
| `Tests/SlashlateTests/OpenRouterClientTests.swift` | Parsing, errores HTTP/red, forma de la request |
| `Tests/SlashlateTests/TriggeredTextTests.swift` | Eliminación del trigger y decisiones de reemplazo |
| `docs/M1_TEST_PLAN.md` | Pruebas manuales |

### Modificados

| Archivo | Cambio |
| --- | --- |
| `Accessibility/AccessibilityService.swift` | La función de M0 que leía y reemplazaba en un paso se dividió en `captureFocusedTextField()` y `replaceText(in:expectedValue:with:)`. Necesario porque ahora hay una espera asíncrona entre leer y escribir. La lectura/escritura AX es la misma de M0. |
| `AppState.swift` | `@MainActor`, flujo async, una traducción a la vez, guardado de API key |
| `UI/MenuBarView.swift` | Sección "OpenRouter API Key" (✓ Configured / Replace API Key), etiqueta M1 |
| `Package.swift` | Target de tests `SlashlateTests` |
| `Makefile` | `make test` |
| `scripts/build-app.sh` | Firma opcional con `SLASHLATE_SIGN_IDENTITY` |
| `README.md`, `AGENTS.md` | Documentación de M1 |

## OpenRouter

- `POST https://openrouter.ai/api/v1/chat/completions` vía `URLSession`, sin
  SDKs.
- Modelo: `openai/gpt-5-nano`, definido solo en `OpenRouterConfiguration`.
- `reasoning: { effort: "minimal", exclude: true }`: gpt-5-nano es un modelo
  de razonamiento; con esfuerzo mínimo una frase corta se traduce en ~1-2 s.
  Se desactiva poniendo `reasoningEffort = nil`.
- Timeout de 10 s (request y resource), sesión `ephemeral` (sin caché en
  disco).
- Se extrae solo `choices[0].message.content` y se hace trim de whitespace
  externo; los saltos de línea internos se conservan.
- Errores mapeados: sin API key, fallo de Keychain, sin red, timeout, 401/403,
  402 (sin créditos), 429, otros HTTP, JSON inválido, sin `choices`, sin
  `content`, contenido vacío, y errores que OpenRouter devuelve dentro de un
  200. Ningún mensaje incluye la API key.

## API key y Keychain

- Se guarda como generic password en el login Keychain (servicio
  `dev.hectoracosta.slashlate`, cuenta `openrouter-api-key`, etiqueta
  "Slashlate OpenRouter API Key"). Nunca en código, `UserDefaults` ni logs.
- Al guardar, el item se **borra y se recrea** en vez de actualizarse, para
  que su lista de acceso confíe en la versión actual de la app.
- Se lee **una vez por arranque** y queda en memoria. Antes se leía en cada
  traducción, lo que provocaba el diálogo de contraseña del Keychain en cada
  uso.

## Problema encontrado: firma ad-hoc y permisos

### Síntoma

1. Accessibility aparecía activado en System Settings, pero Slashlate decía
   "Accessibility required".
2. El Keychain pedía la contraseña del Mac en cada traducción.

### Causa

`make app` firmaba ad-hoc (`codesign --sign -`). macOS identifica una app
ad-hoc por el **hash del binario** (`designated => cdhash ...`), así que cada
rebuild es, para el sistema, una app distinta:

- el permiso de Accessibility (TCC) seguía apuntando al binario anterior;
- el item del Keychain solo confiaba en el binario que lo creó.

### Solución

`scripts/build-app.sh` acepta `SLASHLATE_SIGN_IDENTITY`. Con un certificado
"Apple Development" el requisito pasa a ser *bundle ID + certificado*, que no
cambia entre rebuilds:

```bash
security find-identity -v -p codesigning
export SLASHLATE_SIGN_IDENTITY="<hash del certificado>"
make run
```

Sin la variable se sigue firmando ad-hoc (útil para contribuidores sin
certificado).

Para limpiar un permiso de Accessibility obsoleto:

```bash
tccutil reset Accessibility dev.hectoracosta.slashlate
```

y volver a concederlo.

### Estado actual

Se firma con un certificado "Apple Development" propio, creado desde Xcode
con una cuenta gratuita. `SLASHLATE_SIGN_IDENTITY` está definido en
`~/.zshrc`, por lo que todos los rebuilds conservan Accessibility y el acceso
al Keychain.

### Cómo se creó el certificado (para repetirlo en otro Mac)

No hace falta exportar el certificado: al crearlo en Xcode queda instalado en
el llavero. Exportarlo a `.p12` solo sirve como backup o para otro Mac, y
nunca debe ir al repositorio.

1. Xcode → Settings → Accounts → **+** → Apple ID (cuenta gratuita sirve).
2. Manage Certificates → **+** → **Apple Development**.
3. `security find-identity -v -p codesigning` → copiar el hash del nuevo
   certificado.
4. Añadir a `~/.zshrc`: `export SLASHLATE_SIGN_IDENTITY="<hash>"`.
5. `make run`, luego `tccutil reset Accessibility dev.hectoracosta.slashlate`
   y conceder Accessibility de nuevo.
6. En Slashlate: **Replace API Key** → pegar la key → **Save**. Si aparece el
   diálogo del Keychain, **Always Allow** (no "Allow").

Después de esto no debería volver a pedirse ningún permiso en los rebuilds.

## Tests

`make test` - 23 tests, sin llamadas reales a OpenRouter:

- respuesta válida; trim externo conservando saltos de línea;
- sin `choices`, `choices` vacío, sin `content`, `content` vacío, JSON
  inválido;
- mapeo de HTTP 401/402/429/5xx y de errores dentro de un 200;
- mapeo de timeout y sin red;
- forma de la request (headers, modelo, mensajes);
- API key ausente falla antes de hacer la request;
- eliminación del trigger (incluyendo URLs con `///` y saltos de línea);
- no reemplazar si el usuario siguió escribiendo, borró texto, el valor no se
  puede leer o el foco cambió.

Accessibility no tiene tests unitarios; se valida manualmente
(`M1_TEST_PLAN.md`).

## Limitaciones conocidas

- En algunos editores web (ChatGPT, Slack) el elemento AX podría no
  reconocerse como "el mismo" tras la espera. En ese caso la traducción se
  descarta (lado seguro) pero no se aplica. Pendiente de verificar.
- La traducción reemplaza el contenido completo del campo, igual que M0.
- Fuera de alcance en M1: múltiples idiomas, triggers configurables, selector
  de modelos, streaming, historial, ventana de settings.
