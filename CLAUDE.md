# CLAUDE.md — Gastos Casa

> Mapa de arquitectura de **Gastos Casa**: app de gastos compartidos del
> hogar. Misma filosofía que **StockMerger**
> (`juliobarbol/stockmerger`): PWA de un solo archivo, local-first, nube
> opcional, servida como assets estáticos en Cloudflare.

## Qué es

Una app para anotar los gastos de la casa desde el teléfono. Desde acá se:

- **Cargan gastos** con un teclado numérico grande (monto → categoría → quién
  pagó → descripción/etiquetas/fecha opcionales). Por defecto el gasto es de
  hoy, pero se puede **fechar otro día** (📅 HOY / AYER / la que sea).
- Se lleva **quién gastó qué**: cada gasto queda a nombre de una persona y el
  resumen dice cómo queda la cuenta si parten todo a la mitad.
- **Cada uno se crea su cuenta desde la app** (no hay personas quemadas en el
  código ni altas a mano en el panel de Supabase).
- Se ven el **historial** del mes (filtrable por persona, categoría y
  etiqueta) y un **resumen** con dona por categoría, evolución mensual,
  día más caro, día de la semana más caro, gastos hormiga y comparativa
  contra el mes anterior.
- Se **navega entre meses** (‹ ›) en historial y resumen: se puede volver a
  cualquier mes con datos, no solo al actual.
- Se configuran **gastos fijos** mensuales, **límites** por categoría y
  **categorías** propias (nombre, emoji, color, si cuenta como esencial).
- Se **sincroniza en tiempo real** con el otro teléfono vía Supabase, con
  usuario propio por persona.

## Forma del proyecto

- **PWA de un solo archivo**: toda la app está en `index.html` (~3.100
  líneas, HTML + CSS + JS inline). No hay build step ni bundler.
- Se sirve como **assets estáticos en Cloudflare** (`wrangler.jsonc`,
  `assets.directory: "."`).
- `sw.js` + `manifest.webmanifest` la hacen instalable y offline-first.
- Dependencias externas por CDN: librería de Supabase (jsdelivr) y la fuente
  IBM Plex Mono (Google Fonts). Nada más.
- No hay tests ni linters; es HTML+JS plano servido estático.

## ⚠️ Trabajar sin quemar tokens — LEER PRIMERO

`index.html` pesa **~160 KB / ~3.090 líneas**. Es bastante más chico que el
de StockMerger, pero vale la misma disciplina: está limpio y modularizado
(líneas cortas, sin minificados ni base64, banners `// XXX.JS`), así que la
**lectura por rangos de línea es exacta y barata**. Reglas:

1. Para localizar algo: `Grep -n` del símbolo/función/string → te da la línea
   exacta → `Read` con `offset`/`limit` solo ese tramo (±30 líneas).
2. Para saltar a un módulo: usá la columna **Líneas** de la tabla de abajo y
   `Read` ese rango directamente.
3. Para **editar**: `Grep` el `old_string` único → `Read` solo esa franja →
   `Edit`. No vuelvas a leer el archivo después de editar (el harness ya
   valida el cambio).
4. **CSS (`<style>` 26–444)** y **HTML/markup (446–879)** casi nunca hacen
   falta para lógica de negocio — no los leas salvo trabajo de estilos o
   maquetado.

### Mapa de navegación (rangos de línea)

| Región | Líneas |
|---|---|
| `<head>` + CDN + script de tema | 1–25 |
| **CSS** (`<style>`) | 26–444 |
| **HTML / markup** (gate, header, vistas, modales) | 446–879 |
| **JS principal** (`<script>`) | 880–3084 |

### Módulos internos (dentro del JS principal)

Cada módulo arranca con un banner `// XXX.JS — ...`. Saltá directo al rango:

| Módulo | Líneas | Rol |
|---|---|---|
| `CONST.JS` | 895–931 | Categorías y personas por defecto, teclas, emojis/colores, claves de localStorage. |
| `STORE.JS` | 932–938 | `load()` / `save()` sobre localStorage. Todo el volumen de datos es chico; no hace falta IndexedDB. |
| `STATE.JS` | 939–980 | Estado global: `expenses`, `recurring`, `budgets`, `CATEGORIES`, `PEOPLE`, `meId`, config de nube, `viewMonth` (el mes que se está mirando). |
| `UTILS.JS` | 981–1075 | `uid()`, `fmt()`, `pkey()` (clave normalizada de persona), `liveExpenses()` (filtra lápidas), `escapeHtml()` y los **helpers de fecha/mes** (`ymd()`, `monthOf()`, `isoFromYMD()`, `shiftMonth()`, `monthAnchorISO()`). |
| `MUTATE.JS` | 1076–1143 | **Toda escritura pasa por acá**: marca `updatedAt` + `_dirty` y dispara el push a la nube. Incluye borrado lógico, purga de lápidas y migración de datos viejos. |
| `PEOPLE.JS` | 1144–1283 | Quién es quién: chip de usuario, selector "PAGÓ", modal "¿quién soy?", alta/baja de personas. **No hay personas precargadas.** |
| `UI.JS` | 1284–1476 | Piezas compartidas: confirm propio, navegación entre vistas, **navegador de mes** (`setViewMonth()`), chip de fecha, display del monto, grilla de categorías, teclado, punto de sincronización. |
| `TAGS.JS` | 1477–1519 | Etiquetas libres por gasto (máx. 5). |
| `HOME.JS` | 1520–1587 | Pantalla de alta de gastos. |
| `HISTORIAL.JS` | 1588–1700 | Lista del mes + filtros (persona / categoría / etiqueta) + swipe para borrar. |
| `EDIT.JS` | 1701–1748 | Modal de edición de un gasto (incluye cambiar quién pagó y **la fecha**). |
| `DONUT.JS` | 1749–1848 | Dona de distribución por categoría, en SVG a mano (sin librerías de charts). |
| `WHO.JS` | 1849–1913 | **Quién gastó**: totales por persona y balance "si parten todo a la mitad". |
| `RESUMEN.JS` | 1914–2111 | Números del mes, evolución, día más caro, día de la semana, gastos hormiga, comparativa mes anterior, barras por categoría. |
| `RECUR.JS` | 2112–2192 | Gastos fijos mensuales y "aplicar al mes". |
| `BUDGET.JS` | 2193–2219 | Límite mensual por categoría. |
| `CATS.JS` | 2220–2320 | Administrador de categorías (nombre, emoji, color, esencial). |
| `DATA.JS` | 2321–2399 | Exportar CSV / backup JSON, importar, borrar todo. |
| `SUPABASE.JS` | 2400–2602 | Conexión **opcional** con la nube: config, login, **alta de cuenta (`sbSignUp`)**, `casaJoin()`, sesión, `pullMembers()` / `pullCasa()`. |
| `SYNC.JS` | 2603–2781 | Motor de sincronización: push de lo sucio, pull incremental, merge last-write-wins. |
| `REALTIME.JS` | 2782–2815 | Suscripción a `postgres_changes` (gastos, fijos, config y **personas**): lo que carga el otro aparece solo. |
| `GATE.JS` | 2816–2946 | Pantalla de entrada con 3 modos: `login` / `signup` / `join`. Tapa la app cuando la nube está configurada. |
| `NUBE_UI.JS` | 2947–3025 | Sección ☁ NUBE COMPARTIDA de la pestaña DATOS. |
| `THEME.JS` | 3026–3042 | Tema claro / oscuro. |
| `BOOT.JS` | 3043–3084 | Arranque, listeners de re-sync y registro del service worker. |

> Los rangos se mueven al editar. Si algo no cuadra, reubicá con
> `Grep -n "^// NOMBRE.JS"` y leé el banner.

### Pestañas de la UI

`AGREGAR` (alta de gastos), `HISTORIAL`, `RESUMEN`, `FIJOS`, `LÍMITES`,
`CATEG.`, `DATOS` (nube, personas, backups, zona de peligro).

## Persistencia

1. **Local**: todo vive en `localStorage`. Funciona 100% offline.
   - `gastos_data` — gastos
   - `gastos_recurring` — gastos fijos
   - `gastos_budgets` — límites por categoría
   - `gastos_categories` — categorías
   - `gastos_people` — personas de la casa
   - `gastos_me` — quién soy en ESTE teléfono
   - `gastos_theme` — tema claro/oscuro
   - `gastos_sb_config` — `{ url, anonKey, ns }` de la nube
   - `gastos_sync_cursor` — hasta dónde bajamos de cada tabla
   - `gastos_sb_skip` — el usuario eligió "usar sin nube"
2. **Nube (opcional)**: Supabase. Si no se configura, la app funciona igual
   y el intercambio es por backup JSON.

## Conexión con la nube (Supabase)

Config en `localStorage['gastos_sb_config'] = { url, anonKey, ns }`:

- `url` / `anonKey`: del proyecto Supabase.
- **`ns`** = la CASA. **Es la clave que une los teléfonos**: todos tienen que
  usar el mismo `ns` para verse los gastos. Por defecto `casa`.
- El `ns` se elige/confirma en el gate al crear la cuenta y se guarda acá
  (`guardarCasaElegida()`).

Cliente creado con `supabase.createClient(url, anonKey, { auth: {
persistSession, autoRefreshToken, storageKey: 'gastos-auth' } })` — ver
`sbInit()`. La sesión queda en `localStorage` y sobrevive recargas.

### Acceso por persona (Supabase Auth + RLS)

La anon key **no abre la base por sí sola**. Cada persona tiene un usuario de
Supabase Auth (email + contraseña) y una fila en `casa_members` con su casa
(`ns`), su nombre para mostrar y su color. Las policies consultan eso con el
helper `casa_is_member(ns)`; sin sesión iniciada (`auth.uid()` null) no se ve
ni se toca nada.

#### Alta de cuenta: la hace el usuario, no el admin

**No hay personas precargadas ni altas a mano.** Cualquiera abre la app y se
crea su cuenta desde el gate (pestaña CREAR CUENTA): nombre, email,
contraseña, nombre de la casa y **código de la casa**.

- `sbSignUp()` → `auth.signUp()`. Si el proyecto pide confirmar el mail, la
  sesión viene en `null`: la app lo avisa y lo manda a ENTRAR.
- `casaJoin()` → RPC **`casa_join(p_ns, p_code, p_name, p_color)`**, que es
  `security definer` porque escribe en tablas donde el cliente no tiene
  permiso. Solo escribe la fila de `auth.uid()`; no acepta un user_id ajeno.
  - Si la casa **no existe**, la crea y el código que mandó queda como el
    código de esa casa (el primero la funda).
  - Si la casa **ya existe**, exige el código exacto. Si no coincide, falla y
    la persona no ve nada.
- El código se ve en DATOS → ☁ Nube ("Código para invitar", `pullCasa()`),
  solo para quienes ya son miembros — lo garantiza la RLS de `casa_houses`.

> ⚠️ **El código es lo único que separa una casa de los curiosos.** Sin él,
> cualquiera que abra la app y tipee el nombre de la casa vería los gastos del
> hogar. Si se filtra: `update casa_houses set code = '...' where ns = '...'`
> (los que ya son miembros no se ven afectados; el código solo se pide al
> entrar por primera vez).

#### Los tres modos del gate (`GATE.JS`)

| Modo | Cuándo | Campos |
|---|---|---|
| `login`  | Por defecto | email + contraseña |
| `signup` | Pestaña CREAR CUENTA | nombre, email, contraseña, casa, código |
| `join`   | Hay sesión pero **no** es miembro de la casa | nombre, casa, código |

El modo `join` es la red de seguridad: le pasa a quien confirmó el mail y
volvió a entrar, y a quien se creó la cuenta pero puso mal el código (la
cuenta ya existe, así que reintentar el alta daría "user already registered"
— por eso se reintenta solo el `casa_join`).

- **Gate al abrir** (`#auth-gate`, `gateRefresh()`): si la nube está
  configurada y no hay sesión (o la hay pero falta unirse a la casa), una
  pantalla tapa la app. No aparece en modo sin nube. Tiene dos escapes:
  "Configurar conexión" (va a DATOS) y "Usar sin nube (solo este teléfono)" —
  ambos marcan `gastos_sb_skip`, que se limpia al volver a entrar.
- **Identidad**: con sesión iniciada, quién soy lo define `casa_members`
  (`aplicarIdentidad()`): el chip del header queda fijo y el selector "PAGÓ"
  del alta queda bloqueado en mi nombre. Sin nube, se elige a mano tocando el
  chip del header (y la primera persona se crea desde el propio selector
  "PAGÓ", que arranca en "+ ¿Quién sos?").
- **Baja de personas**: borrar el usuario en Supabase Auth. El
  `on delete cascade` borra la membresía → el teléfono queda sin acceso al
  instante (los gastos que cargó NO se borran).

### Tablas

| Tabla | Uso desde la app |
|---|---|
| `casa_houses` | **Lee** el código de la casa (para poder invitar). Solo escribe `casa_join()`. |
| `casa_members` | **Lee** (pull + Realtime). Quién es quién en la casa. El alta la hace `casa_join()` cuando la persona se registra; cada uno puede editar solo SU fila. |
| `casa_expenses` | **Lee y escribe** (upsert por `(ns, id)`). Una fila por gasto. |
| `casa_recurring` | **Lee y escribe**. Una fila por gasto fijo. |
| `casa_settings` | **Lee y escribe**. Config compartida: `categories`, `budgets`, `people` (una fila por clave). |

Realtime: se suscribe a `postgres_changes` (`event: "*"`) en las tres tablas
de datos **y en `casa_members`** (para que quien se acaba de registrar
aparezca al instante en el teléfono del otro), filtrando por `ns`.

### Cómo sincroniza (`SYNC.JS`)

```
   Teléfono de Julio                                Teléfono de Javiera
   ─────────────────                                ───────────────────
  carga un gasto
       │  _dirty = true, updatedAt = ahora
       │  schedulePush() (debounce 700 ms)
       ▼
  upsert casa_expenses ────────────►  Realtime postgres_changes
              (Supabase)                        │
                                                ▼
                                        mergeExpenseRow() → repinta
```

Reglas del motor, que hay que respetar si se toca:

- **Fila por gasto, no un blob.** Dos personas cargando al mismo tiempo no se
  pisan el archivo entero.
- **Borrado lógico** (`deleted = true`), no `DELETE`. Un borrado tiene que
  poder viajar al otro teléfono; si borráramos la fila, el otro nunca se
  enteraría y la resucitaría en el próximo push. Las lápidas se purgan
  localmente a los **120 días** (`TOMBSTONE_DAYS`).
- **Last-write-wins por `updated_at`** (lo escribe la app). En empate gana lo
  local, para que el eco de nuestro propio push no pise un cambio recién
  hecho.
- **El cursor de bajada es `synced_at`** (lo escribe un trigger del servidor),
  NO `updated_at`. Así un teléfono con el reloj atrasado no se pierde
  cambios. Hay un cursor por tabla en `gastos_sync_cursor`.
- **`_dirty`** marca lo que todavía no subió. Se reintenta al volver la
  conexión, al volver la app al frente y en un barrido cada 5 minutos.
  `_dirty` es local: nunca se sube ni se exporta.
- **IDs**: `uid()` (timestamp base36 + random). No usar `Date.now()` solo —
  dos teléfonos cargando en el mismo milisegundo chocarían.
- **Toda escritura pasa por `MUTATE.JS`** (`addExpenseRecord`,
  `deleteExpense`, `touchExpense` + `persist*`). Tocar `expenses` directo
  desde una vista es un bug: el cambio no viaja.

## Decisiones de producto (de Julio) — fuente de verdad

> ⚠️ **Mantener al día**: si Julio cambia alguna de estas reglas, hay que
> EDITAR esta sección en el mismo cambio.

- **Local-first, nube opcional.** La app tiene que funcionar entera sin
  internet y sin Supabase configurado. Nada de features que dependan de la
  nube para lo básico (cargar y ver gastos).
- **Cada gasto tiene dueño.** Siempre se registra quién pagó. Con nube, es
  quien tiene la sesión iniciada (no se puede falsear desde el alta); sin
  nube, se elige a mano en el selector "PAGÓ". El botón de registrar queda
  deshabilitado hasta que haya persona elegida.
- **Nadie viene precargado.** `DEFAULT_PEOPLE` está vacío a propósito: la app
  es genérica, no la de dos personas concretas. Cada uno se crea su cuenta
  desde el gate; sin nube, se crea a sí mismo desde el selector "PAGÓ".
  **No volver a quemar nombres en el código.**
- **Cualquiera puede registrarse, pero no en cualquier casa.** El alta es
  libre; entrar a una casa existente pide su código. La primera persona que
  usa un nombre de casa la funda y define el código.
- **La lista de personas es de la casa, no del teléfono.** Con nube, manda
  `casa_members`. También viaja por `casa_settings/people` para el modo sin
  nube. El cruce persona↔gasto es **por nombre normalizado** (`pkey()`),
  igual que en StockMerger con los clientes.
- **Borrar una persona no borra sus gastos.** Solo deja de aparecer para
  elegir; el histórico se conserva a su nombre.
- **La fecha manda sobre el mes.** El `month` de un gasto se DERIVA de su
  `date` (`monthOf()`), siempre en hora local — con UTC, un gasto del 31 a
  las 22:00 en Chile caería en el mes siguiente. Nunca escribir `month` a
  mano. En el alta la fecha arranca en HOY y se puede cambiar a cualquier día
  pasado (no futuro); al registrar **no se resetea**, para poder cargar
  varios gastos del mismo día viejo seguidos — el chip queda en dorado
  avisando que no es hoy.
- **`viewMonth` es el mes que se está mirando; `currentMonth` es el de hoy y
  no se mueve.** Historial, resumen y el total del pie siguen a `viewMonth`
  (`monthlyEx()` filtra por ahí). Se navega con ‹ › entre el mes más viejo
  con datos y el actual; tocando una barra de la evolución o una fila del
  historial mensual también se salta a ese mes. Si un gasto se guarda o se
  edita hacia otro mes, la app **se mueve a ese mes**: si no, el total de
  abajo no cambia y parece que no se guardó nada.
- **"Aplicar gastos fijos" va al mes que se está mirando**, no siempre al
  actual (así se puede completar un mes pasado). El confirm dice a qué mes.
- **El balance del resumen es informativo**, no un libro de cuentas: asume
  50/50 y dice quién le debe cuánto a quién este mes. No hay registro de
  pagos entre las dos personas (si algún día hace falta, es feature nueva).
- **Categorías, límites y personas son compartidos** (viajan por
  `casa_settings`). El tema claro/oscuro y "quién soy" son de cada teléfono.
- **"Borrar todos los datos"** borra para los dos si hay nube (marca todo
  como borrado y lo sincroniza). El texto del confirm lo dice explícito.
- **Moneda**: se formatea con `toLocaleString("es-CL")` y símbolo `$`, sin
  decimales (los montos se redondean al mostrar).
- **La pantalla de alta llena el alto disponible.** `#app` tiene
  `height:100dvh` (no `min-height`) y las vistas `min-height:0`, así scrollea
  la vista y NO el body: la cabecera y las pestañas quedan siempre visibles.
  En AGREGAR, el teclado es el único que crece (`flex:1`) y se queda con lo
  que sobra, con un piso de 46 px por fila; si no entra (pantalla corta o
  teclado del sistema abierto), la vista scrollea en vez de recortarse.
- **El teclado numérico NO se puede mover.** El alto del `.display` es fijo:
  `.display-preview` y `.last-added` reservan su renglón siempre (se ocultan
  con `.oculto`/`visibility`, **nunca** con `display:none`) y no envuelven a
  dos líneas. Si el display cambia de alto, el teclado se corre solo entre
  tecla y tecla y se termina cargando otro número. Ojo también con los
  nombres de clase: la clase genérica `.empty` (mensajes de lista vacía)
  lleva `padding:40px` — el display del monto usa `.is-empty`, no `.empty`.
  Por lo mismo, el chip de fecha va **en la misma fila** que la descripción
  (`.note-row`): agregarle un renglón propio al alta le robaría alto al
  teclado. Cualquier cosa nueva en AGREGAR tiene que entrar así.
- **Gastos hormiga**: se consideran los de menos de $5.000, y se avisa a
  partir de 3 en la misma categoría en el mes.

## Notas de desarrollo

- **PENDIENTE / ideas**: registrar pagos entre personas (saldar la cuenta del
  mes), gastos divididos en porcentajes distintos a 50/50, notificación push
  cuando el otro carga un gasto grande, poder cambiar el código de la casa
  desde la app (hoy es un `update` a mano en Supabase).
- Para cambios en el shape de los datos, acordate de la **migración**
  (`migrateLegacy()`): hay backups viejos de la app original (v8) sin
  `author`, sin `updatedAt` y con `id` numérico.
- **Acceso directo a Supabase**: si la variable de entorno
  `SUPABASE_ACCESS_TOKEN` está definida, se puede usar con la Management API
  (`api.supabase.com`, endpoint `/v1/projects/<ref>/database/query`) para
  consultar/ajustar la base directamente. ⚠️ **NUNCA commitear
  tokens/secretos al repo**: el repo SE PUBLICA tal cual como app en
  Cloudflare y el historial de git no se borra. La `anonKey` sí es pública
  por diseño, pero igual vive en `localStorage`, no en el código.
- La app **nunca** guarda la contraseña: solo el token de sesión que maneja
  la librería de Supabase.

## Deploy y versión del cache (PWA)

- Se sirve como assets estáticos en Cloudflare desde el repo. `.assetsignore`
  excluye `wrangler.jsonc`, `.assetsignore`, `README.md`, `schema.sql`,
  `CLAUDE.md` y `build.py`.
- El service worker (`sw.js`) sirve el HTML **network-first** (las
  actualizaciones del `index.html` llegan solas) y el resto **cache-first**.
  Las llamadas a `*.supabase.co` **nunca** se cachean.
- La versión del cache (`const CACHE` en `sw.js`) **debe cambiar en cada
  release** para que el SW se actualice. Lo estampa **`build.py`**
  (`CACHE = '<name>-<timestamp UTC>'`, name de `wrangler.jsonc`).
- `build.py` lo corre solo el workflow **`.github/workflows/stamp-sw.yml`** en
  cada push a `main`; si el `sw.js` no venía estampado, lo commitea de vuelta.
  Es la red de seguridad: **no hace falta bump manual**. Igual podés correrlo
  a mano con `python build.py`.
