# Gastos Casa

App para llevar los gastos de la casa desde el teléfono. Cada uno se crea su
cuenta, cada gasto queda anotado a nombre de quien lo pagó, y todos los
teléfonos de la casa ven los gastos **en tiempo real**.

Es una PWA de un solo archivo (`index.html`), sin build step, servida como
assets estáticos en Cloudflare. Anda 100% offline; la nube (Supabase) es
opcional.

---

## Puesta en marcha

### 1. Publicar la app

El repo se sirve tal cual en Cloudflare Workers/Pages (`wrangler.jsonc` ya
está configurado). Cada push a `main` estampa automáticamente la versión del
cache del service worker, así que los teléfonos reciben la última versión
sin hacer nada.

Desde el teléfono: abrir la URL → menú del navegador → **"Agregar a pantalla
de inicio"**. Queda como una app más.

### 2. Crear el proyecto de Supabase (para compartir en tiempo real)

Si no hacés este paso, la app funciona igual, pero cada teléfono ve solo sus
propios gastos.

1. Crear un proyecto en [supabase.com](https://supabase.com) (el plan gratis
   sobra para esto).
2. **SQL Editor** → New query → pegar todo el contenido de
   [`schema.sql`](./schema.sql) → **Run**. Eso crea las tablas, la seguridad
   por usuario (RLS), el alta de cuentas y prende el tiempo real.
3. **Authentication → Sign In / Providers → Email**: apagar **"Confirm
   email"**. Así las cuentas quedan activas al instante. (Si lo dejás
   prendido funciona igual, pero cada persona tiene que confirmar el mail
   antes de poder entrar; la app se lo avisa.)

**No hay que crear usuarios a mano**: cada persona se registra sola desde la
app.

### 3. Conectar cada teléfono

En la app: pestaña **DATOS** → ☁ **NUBE COMPARTIDA**. Cargá la
**URL del proyecto** y la **anon key** (están en Supabase, en
*Project Settings → API*) y guardá.

### 4. Crearse la cuenta

Al abrir la app aparece la pantalla de entrada.

**La primera persona** (funda la casa):

1. Pestaña **CREAR CUENTA**.
2. Nombre, email y contraseña.
3. **Nombre de la casa**: dejalo en `casa` o poné el que quieras.
4. **Código de la casa**: inventalo. Este código queda como el de la casa.

**Las demás personas**: lo mismo, pero poniendo el **mismo nombre de casa y
el mismo código**. Sin el código no pueden entrar, así que es lo que evita
que un desconocido vea los gastos del hogar.

El código lo tenés siempre a mano en **DATOS → ☁ Nube → "Código para
invitar"**, para pasárselo a quien quieras sumar.

Listo: a partir de ahí, lo que carga uno le aparece solo al otro.

El puntito al lado del mes muestra cómo va la sincronización:
🟢 sincronizado · 🟡 subiendo cambios · 🔴 error · ⚫ sin nube.

---

## Cómo se usa

- **AGREGAR** — monto en el teclado, categoría, quién pagó, y listo. Podés
  sumar una descripción y hasta 5 etiquetas. El switch 🔁 lo guarda además
  como gasto fijo mensual.
- **HISTORIAL** — los gastos del mes, filtrables por persona, categoría o
  etiqueta. Deslizá una fila hacia la izquierda para borrarla.
- **RESUMEN** — cuánto puso cada uno y quién le debe cuánto a quién si parten
  todo a la mitad, más la dona por categoría, la evolución mensual y varios
  análisis (día más caro, día de la semana, gastos hormiga, comparación con
  el mes anterior).
- **FIJOS** — los gastos que se repiten todos los meses; "+ APLICAR AL MES"
  los carga de una sin duplicar los que ya estaban.
- **LÍMITES** — cuánto querés gastar como máximo en cada categoría. Cuando
  te pasás, la barra del resumen se pone roja.
- **CATEG.** — categorías propias: nombre, emoji, color y si cuenta como
  gasto esencial (el "mínimo vital" del resumen).
- **DATOS** — nube (conexión, sesión y código para invitar), personas de la
  casa, exportar a CSV o backup JSON, restaurar y borrar todo.

---

## Documentación técnica

- [`CLAUDE.md`](./CLAUDE.md) — arquitectura, mapa de módulos, cómo funciona
  la sincronización y decisiones de producto.
- [`schema.sql`](./schema.sql) — esquema de la base, seguridad (RLS) y la
  función `casa_join` que resuelve el alta de personas.
