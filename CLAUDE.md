# CLAUDE.md — Gastos Casa

> Mapa de arquitectura de **Gastos Casa**: la app de gastos compartidos del
> hogar de Julio y Javiera. Misma filosofía que **StockMerger**
> (`juliobarbol/stockmerger`): PWA de un solo archivo, local-first, nube
> opcional, servida como assets estáticos en Cloudflare.

## Qué es

Una app para anotar los gastos de la casa desde el teléfono. Desde acá se:

- **Cargan gastos** con un teclado numérico grande (monto → categoría → quién
  pagó → descripción/etiquetas opcionales).
- Se lleva **quién gastó qué**: cada gasto queda a nombre de una persona
  (Julio / Javiera) y el resumen dice cómo queda la cuenta si parten todo a
  la mitad.
- Se ven el **historial** del mes (filtrable por persona, categoría y
  etiqueta) y un **resumen** con dona por categoría, evolución mensual,
  día más caro, día de la semana más caro, gastos hormiga y comparativa
  contra el mes anterior.
- Se configuran **gastos fijos** mensuales, **límites** por categoría y
  **categorías** propias (nombre, emoji, color, si cuenta como esencial).
- Se **sincroniza en tiempo real** con el otro teléfono vía Supabase, con
  usuario propio por persona.

## Forma del proyecto

- **PWA de un solo archivo**: toda la app está en `index.html` (~2.600
  líneas, HTML + CSS + JS inline). No hay build step ni bundler.
- Se sirve como **assets estáticos en Cloudflare** (`wrangler.jsonc`,
  `assets.directory: "."`).
- `sw.js` + `manifest.webmanifest` la hacen instalable y offline-first.
- Dependencias externas por CDN: librería de Supabase (jsdelivr) y la fuente
  IBM Plex Mono (Google Fonts). Nada más.
- No hay tests ni linters; es HTML+JS plano servido estático.

## ⚠️ Trabajar sin quemar tokens — LEER PRIMERO

`index.html` pesa **~140 KB / ~2.640 líneas**. Es bastante más chico que el
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
4. **CSS (`<style>` 26–404)** y **HTML/markup (406–806)** casi nunca hacen
   falta para lógica de negocio — no los leas salvo trabajo de estilos o
   maquetado.

### Mapa de navegación (rangos de línea)

| Región | Líneas |
|---|---|
| `<head>` + CDN + script de tema | 1–25 |
| **CSS** (`<style>`) | 26–404 |
| **HTML / markup** (gate, header, vistas, modales) | 406–806 |
| **JS principal** (`<script>`) | 807–2637 |

### Módulos internos (dentro del JS principal)

Cada módulo arranca con un banner `// XXX.JS — ...`. Saltá directo al rango:

| Módulo | Líneas | Rol |
|---|---|---|
| `CONST.JS` | 822–860 | Categorías y personas por defecto, teclas, emojis/colores, claves de localStorage. |
| `STORE.JS` | 861–867 | `load()` / `save()` sobre localStorage. Todo el volumen de datos es chico; no hace falta IndexedDB. |
| `STATE.JS` | 868–903 | Estado global: `expenses`, `recurring`, `budgets`, `CATEGORIES`, `PEOPLE`, `meId`, config de nube. |
| `UTILS.JS` | 904–947 | `uid()`, `fmt()`, `pkey()` (clave normalizada de persona), `liveExpenses()` (filtra lápidas), `escapeHtml()`. |
| `MUTATE.JS` | 948–1012 | **Toda escritura pasa por acá**: marca `updatedAt` + `_dirty` y dispara el push a la nube. Incluye borrado lógico, purga de lápidas y migración de datos viejos. |
| `PEOPLE.JS` | 1013–1132 | Quién es quién: chip de usuario, selector "PAGÓ", modal "¿quién soy?", alta/baja de personas. |
| `UI.JS` | 1133–1262 | Piezas compartidas: confirm propio, navegación entre vistas, display del monto, grilla de categorías, teclado, punto de sincronización. |
| `TAGS.JS` | 1263–1305 | Etiquetas libres por gasto (máx. 5). |
| `HOME.JS` | 1306–1360 | Pantalla de alta de gastos. |
| `HISTORIAL.JS` | 1361–1473 | Lista del mes + filtros (persona / categoría / etiqueta) + swipe para borrar. |
| `EDIT.JS` | 1474–1512 | Modal de edición de un gasto (incluye cambiar quién pagó). |
| `DONUT.JS` | 1513–1612 | Dona de distribución por categoría, en SVG a mano (sin librerías de charts). |
| `WHO.JS` | 1613–1677 | **Quién gastó**: totales por persona y balance "si parten todo a la mitad". |
| `RESUMEN.JS` | 1678–1865 | Números del mes, evolución, día más caro, día de la semana, gastos hormiga, comparativa mes anterior, barras por categoría. |
| `RECUR.JS` | 1866–1941 | Gastos fijos mensuales y "aplicar al mes". |
| `BUDGET.JS` | 1942–1968 | Límite mensual por categoría. |
| `CATS.JS` | 1969–2069 | Administrador de categorías (nombre, emoji, color, esencial). |
| `DATA.JS` | 2070–2148 | Exportar CSV / backup JSON, importar, borrar todo. |
| `SUPABASE.JS` | 2149–2260 | Conexión **opcional** con la nube: config, login/logout, sesión, `pullMembers()`. |
| `SYNC.JS` | 2261–2439 | Motor de sincronización: push de lo sucio, pull incremental, merge last-write-wins. |
| `REALTIME.JS` | 2440–2470 | Suscripción a `postgres_changes`: el gasto que carga el otro aparece solo. |
| `GATE.JS` | 2471–2501 | Pantalla de login que tapa la app cuando la nube está configurada. |
| `NUBE_UI.JS` | 2502–2579 | Sección ☁ NUBE COMPARTIDA de la pestaña DATOS. |
| `THEME.JS` | 2580–2596 | Tema claro / oscuro. |
| `BOOT.JS` | 2597–2636 | Arranque, listeners de re-sync y registro del service worker. |

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
- **`ns`** = la CASA. **Es la clave que une los dos teléfonos**: ambos tienen
  que usar el mismo `ns` para verse los gastos. Por defecto `casa`.

Cliente creado con `supabase.createClient(url, anonKey, { auth: {
persistSession, autoRefreshToken, storageKey: 'gastos-auth' } })` — ver
`sbInit()`. La sesión queda en `localStorage` y sobrevive recargas.

### Acceso por persona (Supabase Auth + RLS)

La anon key **no abre la base por sí sola**. Cada persona tiene un usuario de
Supabase Auth (email + contraseña) y una fila en `casa_members` con su casa
(`ns`), su nombre para mostrar y su color. Las policies consultan eso con el
helper `casa_is_member(ns)`; sin sesión iniciada (`auth.uid()` null) no se ve
ni se toca nada.

- **Gate de login al abrir** (`#auth-gate`, `gateRefresh()`): si la nube está
  configurada y no hay sesión, una pantalla tapa la app hasta iniciar sesión.
  No aparece en modo sin nube. Tiene dos escapes: "Configurar conexión" (va a
  DATOS) y "Usar sin nube (solo este teléfono)" — ambos marcan
  `gastos_sb_skip`, que se limpia solo al volver a iniciar sesión.
- **Identidad**: con sesión iniciada, quién soy lo define `casa_members` (el
  chip del header queda fijo y el selector "PAGÓ" del alta queda bloqueado en
  mi nombre). Sin nube, se elige a mano tocando el chip del header.
- **Alta/baja de personas**: crear/borrar el usuario en Supabase Auth y su
  fila en `casa_members`. El `on delete cascade` borra la membresía al borrar
  el usuario → el teléfono queda sin acceso al instante (los gastos que cargó
  NO se borran). SQL de ejemplo en `schema.sql`, sección 8.

### Tablas

| Tabla | Uso desde la app |
|---|---|
| `casa_members` | **Lee**. Quién es quién en la casa (nombre + color + user_id). El alta se hace en el panel de Supabase, no desde la app. |
| `casa_expenses` | **Lee y escribe** (upsert por `(ns, id)`). Una fila por gasto. |
| `casa_recurring` | **Lee y escribe**. Una fila por gasto fijo. |
| `casa_settings` | **Lee y escribe**. Config compartida: `categories`, `budgets`, `people` (una fila por clave). |

Realtime: se suscribe a `postgres_changes` (`event: "*"`) en las tres tablas
de datos, filtrando por `ns`.

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
- **La lista de personas es de la casa, no del teléfono.** Viaja por
  `casa_settings/people`; las que tienen usuario propio llegan además por
  `casa_members` (que manda para el color y el `user_id`). El cruce
  persona↔gasto es **por nombre normalizado** (`pkey()`), igual que en
  StockMerger con los clientes.
- **Borrar una persona no borra sus gastos.** Solo deja de aparecer para
  elegir; el histórico se conserva a su nombre.
- **El balance del resumen es informativo**, no un libro de cuentas: asume
  50/50 y dice quién le debe cuánto a quién este mes. No hay registro de
  pagos entre las dos personas (si algún día hace falta, es feature nueva).
- **Categorías, límites y personas son compartidos** (viajan por
  `casa_settings`). El tema claro/oscuro y "quién soy" son de cada teléfono.
- **"Borrar todos los datos"** borra para los dos si hay nube (marca todo
  como borrado y lo sincroniza). El texto del confirm lo dice explícito.
- **Moneda**: se formatea con `toLocaleString("es-CL")` y símbolo `$`, sin
  decimales (los montos se redondean al mostrar).
- **Gastos hormiga**: se consideran los de menos de $5.000, y se avisa a
  partir de 3 en la misma categoría en el mes.

## Notas de desarrollo

- **PENDIENTE / ideas**: registrar pagos entre personas (saldar la cuenta del
  mes), gastos divididos en porcentajes distintos a 50/50, notificación push
  cuando el otro carga un gasto grande.
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
