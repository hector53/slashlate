Estamos trabajando en **Slashlate**, una utilidad open source nativa para macOS escrita en Swift/SwiftUI.

Repositorio:

`https://github.com/hector53/slashlate`

Antes de modificar código:

1. Lee completamente `AGENTS.md`.
2. Lee `README.md`.
3. Revisa `docs/M0_TEST_PLAN.md`.
4. Inspecciona la implementación actual en `Sources/Slashlate`.
5. Ejecuta `git status` y asegúrate de no sobrescribir cambios locales del usuario.
6. Ejecuta `swift build` para establecer el baseline.

## Estado actual validado

M0 YA FUNCIONA EN UN MAC REAL.

El usuario ejecutó Slashlate, concedió Accessibility, escribió:

```text
hola mundo ///
```

y Slashlate reemplazó instantáneamente el campo por:

```text
TEST TRANSLATION
```

Por lo tanto, considera validada la arquitectura actual de:

- global keyboard monitoring;
- trigger `///`;
- macOS Accessibility;
- detección del focused text element;
- reemplazo inline;
- menu-bar app.

**No reescribas estas partes sin una razón concreta.**

El objetivo ahora es implementar **M1: traducción real español → inglés con OpenRouter**.

---

# Objetivo de M1

La experiencia esperada es:

```text
ya terminé el cambio y lo subí a staging ///
```

Después de aproximadamente 1–2 segundos:

```text
I've finished the change and deployed it to staging.
```

Todo debe ocurrir **en el mismo campo de texto donde el usuario está escribiendo**.

Slashlate nunca debe pulsar Enter, nunca debe enviar el mensaje y nunca debe abrir una ventana de traducción.

---

# OpenRouter

Usa directamente la API HTTP de OpenRouter mediante `URLSession`.

No agregues SDKs ni dependencias externas salvo que sean estrictamente necesarias.

Endpoint:

```text
POST https://openrouter.ai/api/v1/chat/completions
```

Autenticación:

```text
Authorization: Bearer <API_KEY>
Content-Type: application/json
```

Puedes agregar estos headers opcionales:

```text
X-Title: Slashlate
HTTP-Referer: https://github.com/hector53/slashlate
```

Modelo inicial:

```text
openai/gpt-5-nano
```

El modelo debe estar definido en un único lugar fácil de cambiar posteriormente. No lo disperses como string hardcoded por varios archivos.

M1 solo necesita un modelo.

No implementes todavía selector de modelos.

---

# TranslationService

Crea una abstracción pequeña y clara, por ejemplo:

```text
Translation/
├── TranslationService.swift
├── OpenRouterClient.swift
├── OpenRouterModels.swift
└── TranslationPrompt.swift
```

La arquitectura exacta puede variar si encuentras una alternativa más limpia, pero evita sobreingeniería.

Debe existir una frontera clara para que en el futuro podamos sustituir OpenRouter o agregar otros providers.

Algo conceptualmente parecido a:

```swift
protocol TranslationService {
    func translate(_ text: String) async throws -> String
}
```

La implementación concreta será OpenRouter.

---

# Comportamiento del prompt

Slashlate NO busca una traducción literal de diccionario.

Queremos inglés natural para conversaciones profesionales cotidianas, especialmente comunicación de equipos de software.

El system prompt debe transmitir aproximadamente estas reglas:

```text
Translate the user's text into natural English.

Rules:
- Preserve the original meaning.
- Use natural, friendly professional English.
- Do not sound unnecessarily formal.
- Preserve names, URLs, issue IDs, ticket IDs and technical terminology.
- Preserve code, commands and identifiers.
- Preserve emojis when appropriate.
- Preserve paragraph structure and line breaks where practical.
- The input may contain a mixture of Spanish and English.
- Preserve English that is already natural and translate the Spanish portions.
- Do not add information.
- Do not explain the translation.
- Do not wrap the result in quotes.
- Do not use Markdown code fences.
- Return only the final text.
```

Por ejemplo:

Input:

```text
Hey Paul, ya revise el problema y creo que viene del backend
```

Expected style:

```text
Hey Paul, I've looked into the issue and I think it's coming from the backend.
```

Otro:

```text
listo ya subi el fix, puedes probarlo cuando puedas
```

Expected style:

```text
Done, I've pushed the fix. You can test it whenever you get a chance.
```

No necesitamos obtener exactamente esas frases; sirven para definir el tono.

---

# MUY IMPORTANTE: flujo seguro del texto

La traducción ahora será asíncrona, por lo que NO puedes asumir que el campo activo seguirá siendo el mismo cuando OpenRouter responda.

Este problema debe quedar correctamente resuelto en M1.

Cuando se detecte:

```text
texto original ///
```

haz algo conceptualmente equivalente a:

1. obtener el AXUIElement que actualmente tiene foco;
2. leer su valor;
3. comprobar que termina en `///`;
4. conservar una referencia/snapshot del elemento y del valor original;
5. remover `///` únicamente del texto que se enviará al modelo;
6. NO reemplazar todavía el contenido visible;
7. llamar a OpenRouter;
8. recibir la traducción;
9. volver a consultar EL MISMO elemento;
10. comprobar que su contenido sigue siendo exactamente el texto original con `///`;
11. solamente entonces reemplazarlo por la traducción.

Si mientras espera la respuesta el usuario:

- cambia de aplicación;
- cambia de campo;
- modifica el texto;
- borra parte del mensaje;
- sigue escribiendo;

Slashlate **NO debe sobreescribir ese contenido**.

Esto es un requisito importante de seguridad de interacción.

No uses simplemente:

```text
get currently focused field after API returns
```

porque podríamos terminar reemplazando otro campo distinto.

---

# Fallos de API

Si OpenRouter falla:

```text
hola mundo ///
```

debe permanecer exactamente como estaba.

Nunca reemplaces el contenido por un error.

Nunca borres el texto original.

Nunca elimines `///` de forma permanente antes de recibir una traducción válida.

Los errores deben mostrarse únicamente en el estado de Slashlate en el menu bar.

Maneja razonablemente:

- network unavailable;
- timeout;
- HTTP != 2xx;
- 401 invalid API key;
- 429 rate limit;
- invalid JSON;
- empty response;
- missing `choices`;
- missing `message.content`.

Usa mensajes entendibles.

Ejemplos:

```text
OpenRouter authentication failed
OpenRouter rate limit reached
Translation request timed out
OpenRouter returned an invalid response
```

No hace falta construir un sistema complejo de errores.

---

# API key

Necesitamos introducir la OpenRouter API key sin almacenarla en el código ni en `UserDefaults`.

Aunque la UI completa de Settings pertenece a M2, para poder validar M1 implementa ahora el mínimo necesario.

Usa **macOS Keychain**.

Crea algo como:

```text
Security/
└── KeychainService.swift
```

La API key nunca debe:

- aparecer en Git;
- imprimirse en logs;
- aparecer completa en mensajes de error;
- almacenarse en texto plano.

En el menu-bar popover agrega una sección mínima:

```text
OpenRouter API Key
[ ••••••••••••••• ]

[ Save API Key ]
```

Si existe una API key guardada, no hace falta mostrarla de nuevo. Puedes mostrar:

```text
OpenRouter API Key
✓ Configured

[ Replace API Key ]
```

No construyas todavía una Settings window completa.

El propósito es simplemente poder configurar M1.

---

# Estado mientras traduce

Cuando se detecte `///`:

```text
statusMessage = "Translating..."
```

Cuando termine:

```text
statusMessage = "Translated"
```

En caso de error, muestra el mensaje correspondiente.

No hace falta overlay, spinner flotante ni HUD.

El texto original puede permanecer visible con `///` durante el segundo aproximado que tarde la llamada.

---

# Solicitudes simultáneas

Para M1 mantenlo sencillo.

Solo permite **una traducción activa a la vez**.

Si existe una traducción en progreso y vuelve a detectarse `///`, no inicies otra request accidentalmente.

Diseña esta restricción de forma explícita para que posteriormente podamos cambiarla si queremos.

---

# Timeout

No queremos que una request quede esperando indefinidamente.

Configura un timeout razonable, aproximadamente:

```text
10 segundos
```

Si ocurre timeout:

- conserva el texto original;
- finaliza el estado de loading;
- muestra el error.

---

# Parsing OpenRouter

Modela únicamente el JSON que realmente necesitamos.

Request aproximadamente:

```json
{
  "model": "openai/gpt-5-nano",
  "messages": [
    {
      "role": "system",
      "content": "..."
    },
    {
      "role": "user",
      "content": "..."
    }
  ]
}
```

Response: extrae únicamente:

```text
choices[0].message.content
```

Haz `trim` solamente de whitespace externo producido accidentalmente por el modelo.

No elimines saltos de línea internos.

No introduzcas streaming todavía.

Para mensajes pequeños no lo necesitamos.

---

# No hacer en M1

NO agregues todavía:

- múltiples idiomas;
- `@en`;
- `@es`;
- otros triggers;
- trigger configurable;
- hotkey configurable;
- historial;
- analytics;
- cuentas de usuario;
- auto update;
- launch at login;
- selector de modelos;
- selector de providers;
- streaming;
- traducción offline;
- clipboard fallback;
- onboarding elaborado;
- ventana principal;
- telemetría.

M1 debe seguir siendo pequeño.

---

# Compatibilidad M0

No rompas el comportamiento que ya validamos.

El trigger sigue siendo exactamente:

```text
///
```

El monitor global debe continuar funcionando igual.

La diferencia principal debe ser:

ANTES:

```text
hola ///
→ TEST TRANSLATION
```

AHORA:

```text
hola ///
→ Hello.
```

---

# Tests

Agrega tests unitarios donde aporten valor.

Como mínimo me interesa poder probar sin llamar realmente a OpenRouter:

- parsing de respuesta válida;
- respuesta sin `choices`;
- `content` vacío;
- eliminación del trigger antes de traducir;
- comprobación de que el texto original no debe reemplazarse si cambió durante la request;
- cualquier lógica pura nueva que merezca cobertura.

No intentes unit-testear artificialmente Accessibility si requiere demasiados mocks.

La validación real de Accessibility seguirá haciéndose manualmente en macOS.

---

# Build

Al terminar ejecuta:

```bash
swift build
```

y los tests que hayas agregado.

También ejecuta:

```bash
make app
```

Corrige cualquier warning/error importante introducido por tu implementación.

No declares M1 terminado si no compila.

---

# Documentación

Actualiza `README.md` para explicar:

1. que M0 ya fue validado;
2. que M1 usa OpenRouter;
3. cómo configurar la API key;
4. cómo ejecutar Slashlate;
5. ejemplo real:

```text
ya terminé el cambio ///
↓
I've finished the change.
```

Actualiza `AGENTS.md` para reflejar que el milestone actual pasa a M1.

Crea si resulta útil:

```text
docs/M1_TEST_PLAN.md
```

con pruebas manuales para:

- TextEdit;
- browser textarea;
- ChatGPT;
- mensaje mixto inglés/español;
- API key inválida;
- desconexión de internet;
- modificar el campo mientras se espera la traducción;
- cambiar de aplicación durante la traducción.

---

# Criterios de aceptación

M1 está listo cuando:

A. `hola mundo ///` produce una traducción real al inglés.

B. La traducción reemplaza el contenido en el mismo campo.

C. No se envía automáticamente el mensaje.

D. Una API key inválida no destruye el texto original.

E. Una falla de red no destruye el texto original.

F. Si el usuario modifica el texto mientras OpenRouter responde, Slashlate NO lo sobreescribe.

G. Si el usuario cambia de campo/aplicación durante la request, Slashlate NO reemplaza otro campo.

H. El API key se almacena en Keychain.

I. `swift build` funciona.

J. `make app` genera Slashlate.app.

---

# Al finalizar

No continúes con M2.

Dame un resumen de:

- archivos creados;
- archivos modificados;
- arquitectura final de M1;
- tests ejecutados;
- resultado de `swift build`;
- resultado de `make app`;
- cualquier limitación que deba probar manualmente;
- pasos exactos que debo realizar ahora en mi Mac.

Si encuentras un problema técnico con la implementación existente de M0, corrígelo solamente si es necesario para M1 y explica claramente por qué.

Implementa M1 ahora.