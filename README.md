# Gastos Casa

App para llevar los gastos de la casa desde el teléfono. Cada gasto queda
anotado a nombre de quien lo pagó, y los dos teléfonos se ven los gastos **en
tiempo real**.

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
   por usuario (RLS) y prende el tiempo real.
3. **Authentication → Users → Add user**: crear un usuario por persona
   (email + contraseña). Marcá *Auto Confirm User* para no tener que
   confirmar el mail.
4. Volver al **SQL Editor** y correr el insert de la sección 8 de
   `schema.sql` para darle a cada usuario su nombre y color dentro de la casa.

### 3. Conectar cada teléfono

En la app: pestaña **DATOS** → ☁ **NUBE COMPARTIDA**.

- **URL del proyecto** y **anon key**: están en Supabase, en
  *Project Settings → API*.
- **Casa (namespace)**: dejalo en `casa`. Lo importante es que **los dos
  teléfonos usen el mismo valor**.

Guardar, y después iniciar sesión con el email y la contraseña de cada
persona. Listo: a partir de ahí, lo que carga uno le aparece solo al otro.

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
- **DATOS** — nube, personas de la casa, exportar a CSV o backup JSON,
  restaurar y borrar todo.

---

## Documentación técnica

- [`CLAUDE.md`](./CLAUDE.md) — arquitectura, mapa de módulos, cómo funciona
  la sincronización y decisiones de producto.
- [`schema.sql`](./schema.sql) — esquema de la base, seguridad y alta de
  personas.
