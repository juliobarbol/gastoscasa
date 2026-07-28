-- ════════════════════════════════════════════════════════════════════
-- GASTOS CASA — esquema de Supabase
-- ════════════════════════════════════════════════════════════════════
-- Correr TODO este archivo en el SQL Editor del proyecto de Supabase
-- (Dashboard → SQL Editor → New query → pegar → Run). Es idempotente:
-- se puede volver a correr sin romper nada.
--
-- Modelo: una fila por gasto (no un blob), con borrado lógico y
-- last-write-wins por `updated_at`. El cursor de bajada de la app usa
-- `synced_at`, que lo escribe el servidor con un trigger — así no depende
-- del reloj de los teléfonos.
--
-- `ns` = la CASA (namespace). Los dos teléfonos usan el mismo `ns` para
-- verse los gastos. Por defecto: 'casa'.
--
-- Todas las tablas llevan el prefijo `casa_` a propósito, para poder
-- convivir con otras apps en el mismo proyecto de Supabase sin chocar.
-- ════════════════════════════════════════════════════════════════════


-- ════════════════════════════════════════════════════════════════════
-- 1. PERSONAS DE LA CASA
-- ────────────────────────────────────────────────────────────────────
-- Une un usuario de Supabase Auth con una casa y un nombre para mostrar.
-- Sin fila acá, el usuario NO ve nada (las policies dependen de esto).
-- ════════════════════════════════════════════════════════════════════
create table if not exists casa_members (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  ns         text        not null default 'casa',
  name       text        not null,
  color      text,
  created_at timestamptz not null default now()
);

create index if not exists casa_members_ns_idx on casa_members (ns);

alter table casa_members drop constraint if exists casa_members_name_len;
alter table casa_members add  constraint casa_members_name_len check (char_length(name) between 1 and 40);


-- ════════════════════════════════════════════════════════════════════
-- 2. GASTOS
-- ════════════════════════════════════════════════════════════════════
create table if not exists casa_expenses (
  ns         text        not null,
  id         text        not null,
  amount     numeric     not null,
  category   text        not null,
  note       text,
  tags       jsonb       not null default '[]'::jsonb,
  month      text        not null,             -- 'YYYY-MM'
  date       timestamptz not null,
  recurring  boolean     not null default false,
  author     text,                             -- nombre de quien lo cargó
  author_id  uuid,                             -- su user_id, si tiene usuario
  deleted    boolean     not null default false,
  updated_at timestamptz not null default now(),   -- lo escribe la app (LWW)
  synced_at  timestamptz not null default now(),   -- lo escribe el trigger (cursor)
  primary key (ns, id)
);

create index if not exists casa_expenses_ns_synced_idx on casa_expenses (ns, synced_at);
create index if not exists casa_expenses_ns_month_idx  on casa_expenses (ns, month);

-- Límites de tamaño/forma: la anon key es pública, así que conviene que la
-- base rechace basura aunque alguien juegue con la API a mano.
alter table casa_expenses drop constraint if exists casa_expenses_amount_chk;
alter table casa_expenses add  constraint casa_expenses_amount_chk   check (amount >= 0 and amount < 1e12);
alter table casa_expenses drop constraint if exists casa_expenses_note_len;
alter table casa_expenses add  constraint casa_expenses_note_len     check (note is null or char_length(note) <= 200);
alter table casa_expenses drop constraint if exists casa_expenses_author_len;
alter table casa_expenses add  constraint casa_expenses_author_len   check (author is null or char_length(author) <= 40);
alter table casa_expenses drop constraint if exists casa_expenses_month_chk;
alter table casa_expenses add  constraint casa_expenses_month_chk    check (month ~ '^[0-9]{4}-[0-9]{2}$');
alter table casa_expenses drop constraint if exists casa_expenses_tags_size;
alter table casa_expenses add  constraint casa_expenses_tags_size    check (octet_length(tags::text) <= 2048);


-- ════════════════════════════════════════════════════════════════════
-- 3. GASTOS FIJOS (recurrentes)
-- ════════════════════════════════════════════════════════════════════
create table if not exists casa_recurring (
  ns         text        not null,
  id         text        not null,
  amount     numeric     not null,
  category   text        not null,
  note       text,
  deleted    boolean     not null default false,
  updated_at timestamptz not null default now(),
  synced_at  timestamptz not null default now(),
  primary key (ns, id)
);

create index if not exists casa_recurring_ns_synced_idx on casa_recurring (ns, synced_at);

alter table casa_recurring drop constraint if exists casa_recurring_amount_chk;
alter table casa_recurring add  constraint casa_recurring_amount_chk check (amount >= 0 and amount < 1e12);
alter table casa_recurring drop constraint if exists casa_recurring_note_len;
alter table casa_recurring add  constraint casa_recurring_note_len   check (note is null or char_length(note) <= 200);


-- ════════════════════════════════════════════════════════════════════
-- 4. CONFIG COMPARTIDA (categorías, límites, personas)
-- ────────────────────────────────────────────────────────────────────
-- Una fila por clave: 'categories', 'budgets', 'people'. Es config, no
-- historial: se pisa entera con last-write-wins.
-- ════════════════════════════════════════════════════════════════════
create table if not exists casa_settings (
  ns         text        not null,
  key        text        not null,
  value      jsonb       not null,
  updated_at timestamptz not null default now(),
  synced_at  timestamptz not null default now(),
  primary key (ns, key)
);

create index if not exists casa_settings_ns_synced_idx on casa_settings (ns, synced_at);

alter table casa_settings drop constraint if exists casa_settings_value_size;
alter table casa_settings add  constraint casa_settings_value_size check (octet_length(value::text) <= 262144); -- 256 KB


-- ════════════════════════════════════════════════════════════════════
-- 5. TRIGGER DE `synced_at`
-- ────────────────────────────────────────────────────────────────────
-- El cursor de bajada de la app es `synced_at`. Tiene que ser hora del
-- SERVIDOR y refrescarse en cada escritura; si lo dejáramos en manos del
-- cliente, un teléfono con el reloj atrasado se perdería cambios.
-- ════════════════════════════════════════════════════════════════════
create or replace function public.casa_touch_synced()
returns trigger
language plpgsql
as $$
begin
  new.synced_at := now();
  return new;
end;
$$;

drop trigger if exists casa_expenses_synced  on casa_expenses;
create trigger casa_expenses_synced  before insert or update on casa_expenses
  for each row execute function public.casa_touch_synced();

drop trigger if exists casa_recurring_synced on casa_recurring;
create trigger casa_recurring_synced before insert or update on casa_recurring
  for each row execute function public.casa_touch_synced();

drop trigger if exists casa_settings_synced  on casa_settings;
create trigger casa_settings_synced  before insert or update on casa_settings
  for each row execute function public.casa_touch_synced();


-- ════════════════════════════════════════════════════════════════════
-- 6. RLS — quién ve qué
-- ────────────────────────────────────────────────────────────────────
-- La anon key NO abre la base por sí sola. Cada persona entra con su
-- usuario de Supabase Auth, y solo ve las filas de la(s) casa(s) donde
-- tiene una fila en casa_members. Sin sesión (auth.uid() null) no se ve
-- ni se toca nada.
-- ════════════════════════════════════════════════════════════════════
create or replace function public.casa_is_member(p_ns text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from casa_members m
    where m.user_id = auth.uid() and m.ns = p_ns
  );
$$;

revoke all on function public.casa_is_member(text) from public;
grant execute on function public.casa_is_member(text) to authenticated;

alter table casa_members   enable row level security;
alter table casa_expenses  enable row level security;
alter table casa_recurring enable row level security;
alter table casa_settings  enable row level security;

-- casa_members: se LEE (para saber quién es quién en la casa), pero el alta
-- y la baja de personas se hacen desde el panel de Supabase, no desde la app.
drop policy if exists casa_members_read on casa_members;
create policy casa_members_read on casa_members
  for select to authenticated using (casa_is_member(ns));

-- Gastos / fijos / config: los miembros de la casa pueden todo.
-- (Los borrados de la app son lógicos —`deleted = true`— así que en la
--  práctica todo pasa por insert y update; igual dejamos delete abierto
--  para poder limpiar a mano desde el panel.)
drop policy if exists casa_expenses_all on casa_expenses;
create policy casa_expenses_all on casa_expenses
  for all to authenticated using (casa_is_member(ns)) with check (casa_is_member(ns));

drop policy if exists casa_recurring_all on casa_recurring;
create policy casa_recurring_all on casa_recurring
  for all to authenticated using (casa_is_member(ns)) with check (casa_is_member(ns));

drop policy if exists casa_settings_all on casa_settings;
create policy casa_settings_all on casa_settings
  for all to authenticated using (casa_is_member(ns)) with check (casa_is_member(ns));


-- ════════════════════════════════════════════════════════════════════
-- 7. REALTIME
-- ────────────────────────────────────────────────────────────────────
-- Sin esto, el gasto que carga una persona NO le aparece sola a la otra
-- (habría que abrir y cerrar la app para que sincronice).
-- ════════════════════════════════════════════════════════════════════
do $$
begin
  begin execute 'alter publication supabase_realtime add table casa_expenses';  exception when duplicate_object then null; end;
  begin execute 'alter publication supabase_realtime add table casa_recurring'; exception when duplicate_object then null; end;
  begin execute 'alter publication supabase_realtime add table casa_settings';  exception when duplicate_object then null; end;
end $$;

-- Realtime respeta RLS, pero necesita ver la fila completa en los UPDATE
-- y DELETE para poder filtrar por `ns`.
alter table casa_expenses  replica identity full;
alter table casa_recurring replica identity full;
alter table casa_settings  replica identity full;


-- ════════════════════════════════════════════════════════════════════
-- 8. ALTA DE PERSONAS
-- ────────────────────────────────────────────────────────────────────
-- 1) Dashboard → Authentication → Users → "Add user" → email + contraseña
--    (marcar "Auto Confirm User" para que no tenga que confirmar el mail).
-- 2) Copiar el UUID del usuario recién creado.
-- 3) Correr acá abajo el insert con ese UUID.
--
-- Para dar de baja a alguien: borrar el usuario en Authentication. El
-- `on delete cascade` le borra la fila de casa_members y el teléfono queda
-- sin acceso al instante (los gastos que cargó NO se borran).
-- ════════════════════════════════════════════════════════════════════

-- insert into casa_members (user_id, ns, name, color) values
--   ('00000000-0000-0000-0000-000000000000', 'casa', 'Julio',   '#f59e0b'),
--   ('11111111-1111-1111-1111-111111111111', 'casa', 'Javiera', '#ec4899')
-- on conflict (user_id) do update
--   set ns = excluded.ns, name = excluded.name, color = excluded.color;

-- Atajo: dar de alta por email, sin copiar UUIDs a mano.
-- (Correr DESPUÉS de crear los usuarios en Authentication → Users.)
--
-- insert into casa_members (user_id, ns, name, color)
-- select u.id, 'casa', v.name, v.color
-- from auth.users u
-- join (values
--   ('julio@ejemplo.com',   'Julio',   '#f59e0b'),
--   ('javiera@ejemplo.com', 'Javiera', '#ec4899')
-- ) as v(email, name, color) on lower(u.email) = lower(v.email)
-- on conflict (user_id) do update
--   set ns = excluded.ns, name = excluded.name, color = excluded.color;


-- ════════════════════════════════════════════════════════════════════
-- 9. CONSULTAS ÚTILES (para mirar desde el SQL Editor)
-- ════════════════════════════════════════════════════════════════════
-- Total del mes por persona:
--   select author, sum(amount) as total, count(*) as gastos
--   from casa_expenses
--   where ns = 'casa' and month = to_char(now(), 'YYYY-MM') and not deleted
--   group by author order by total desc;
--
-- Últimos gastos cargados:
--   select date, author, category, amount, note
--   from casa_expenses
--   where ns = 'casa' and not deleted
--   order by date desc limit 30;
