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
-- 0. LAS CASAS
-- ────────────────────────────────────────────────────────────────────
-- Cada casa tiene un código. El primero que se registra con un nombre de
-- casa la CREA y define su código; el resto necesita ese código para
-- entrar. Sin esto, cualquiera que adivine el nombre de la casa ("casa")
-- vería los gastos del hogar.
-- ════════════════════════════════════════════════════════════════════
create table if not exists casa_houses (
  ns         text primary key,
  code       text        not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table casa_houses drop constraint if exists casa_houses_ns_len;
alter table casa_houses add  constraint casa_houses_ns_len   check (char_length(ns) between 2 and 30);
alter table casa_houses drop constraint if exists casa_houses_code_len;
alter table casa_houses add  constraint casa_houses_code_len check (char_length(code) between 4 and 40);


-- ════════════════════════════════════════════════════════════════════
-- 1. PERSONAS DE LA CASA
-- ────────────────────────────────────────────────────────────────────
-- Une un usuario de Supabase Auth con una casa y un nombre para mostrar.
-- Sin fila acá, el usuario NO ve nada (las policies dependen de esto).
-- La fila la crea la función casa_join() cuando la persona se registra
-- desde la app: no hay que darla de alta a mano.
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

alter table casa_houses    enable row level security;
alter table casa_members   enable row level security;
alter table casa_expenses  enable row level security;
alter table casa_recurring enable row level security;
alter table casa_settings  enable row level security;

-- casa_members: se LEE (para saber quién es quién en la casa). El alta la
-- hace casa_join() (security definer), no el cliente; y cada uno puede
-- cambiar SU nombre y color, nunca los de otro.
drop policy if exists casa_members_read on casa_members;
create policy casa_members_read on casa_members
  for select to authenticated using (casa_is_member(ns));

drop policy if exists casa_members_update_self on casa_members;
create policy casa_members_update_self on casa_members
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- casa_houses: el código de la casa lo ven SOLO sus miembros (es lo que se
-- usa para invitar). Nadie escribe acá directamente: solo casa_join().
drop policy if exists casa_houses_read on casa_houses;
create policy casa_houses_read on casa_houses
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
-- 6 bis. ENTRAR A UNA CASA (lo que usa el botón "CREAR CUENTA" de la app)
-- ────────────────────────────────────────────────────────────────────
-- Cualquiera puede crearse un usuario desde la app. Este es el paso que
-- lo mete en una casa:
--
--   · Si la casa NO existe → la crea, y el código que mandó queda como el
--     código de esa casa. Quien la crea, la "funda".
--   · Si la casa YA existe → exige el código correcto. Si no coincide,
--     falla y no se ve nada.
--
-- Es `security definer` a propósito: necesita escribir en casa_houses y
-- casa_members, donde el cliente no tiene permiso de escritura. Solo
-- escribe la fila del usuario que la llama (auth.uid()); no acepta que le
-- pasen un user_id.
-- ════════════════════════════════════════════════════════════════════
create or replace function public.casa_join(
  p_ns    text,
  p_code  text,
  p_name  text,
  p_color text default null
)
returns casa_members
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_ns    text := lower(btrim(coalesce(p_ns, '')));
  v_code  text := btrim(coalesce(p_code, ''));
  v_name  text := btrim(coalesce(p_name, ''));
  v_house casa_houses;
  v_row   casa_members;
begin
  if v_uid is null then
    raise exception 'Hay que iniciar sesión antes de entrar a una casa.';
  end if;
  if char_length(v_ns) < 2 then
    raise exception 'El nombre de la casa es muy corto.';
  end if;
  if char_length(v_code) < 4 then
    raise exception 'El codigo de la casa tiene que tener al menos 4 caracteres.';
  end if;
  if char_length(v_name) < 1 then
    raise exception 'Falta tu nombre.';
  end if;

  select * into v_house from casa_houses where ns = v_ns;

  if v_house is null then
    -- Primera persona: funda la casa con este código.
    insert into casa_houses (ns, code, created_by) values (v_ns, v_code, v_uid)
    on conflict (ns) do nothing
    returning * into v_house;
    -- Si dos se registran a la vez, el que perdió la carrera valida contra
    -- la casa que quedó creada.
    if v_house is null then
      select * into v_house from casa_houses where ns = v_ns;
    end if;
  end if;

  if v_house.code <> v_code then
    raise exception 'El codigo de la casa no es correcto.';
  end if;

  insert into casa_members (user_id, ns, name, color)
  values (v_uid, v_ns, v_name, coalesce(p_color, '#6b7280'))
  on conflict (user_id) do update
    set ns = excluded.ns, name = excluded.name,
        color = coalesce(excluded.color, casa_members.color)
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.casa_join(text, text, text, text) from public;
grant execute on function public.casa_join(text, text, text, text) to authenticated;


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
  begin execute 'alter publication supabase_realtime add table casa_members';   exception when duplicate_object then null; end;
end $$;

-- Realtime respeta RLS, pero necesita ver la fila completa en los UPDATE
-- y DELETE para poder filtrar por `ns`.
alter table casa_expenses  replica identity full;
alter table casa_recurring replica identity full;
alter table casa_settings  replica identity full;
alter table casa_members   replica identity full;


-- ════════════════════════════════════════════════════════════════════
-- 8. ALTA DE PERSONAS — se hace SOLA, desde la app
-- ────────────────────────────────────────────────────────────────────
-- No hay que dar de alta a nadie a mano. En la app:
--
--   1) Pantalla de entrada → pestaña "CREAR CUENTA".
--   2) Nombre, email, contraseña, nombre de la casa y código de la casa.
--   3) La primera persona FUNDA la casa: el código que escribe queda como
--      el código de esa casa. Después lo ve en DATOS → ☁ Nube ("Código
--      para invitar") y se lo pasa a quien quiera sumar.
--   4) El resto entra con ese mismo nombre de casa + código.
--
-- Recomendado para que el alta sea inmediata: Dashboard → Authentication →
-- Sign In / Providers → Email → apagar "Confirm email". Si queda prendido,
-- la persona tiene que confirmar el mail antes de poder entrar (la app se
-- lo avisa).
--
-- Para dar de baja a alguien: borrar el usuario en Authentication. El
-- `on delete cascade` le borra la fila de casa_members y el teléfono queda
-- sin acceso al instante (los gastos que cargó NO se borran).
--
-- Cambiar el código de una casa (si se filtró):
--   update casa_houses set code = 'nuevo-codigo' where ns = 'casa';
--
-- Ver quién está en cada casa:
--   select h.ns, h.code, m.name, u.email
--   from casa_houses h
--   left join casa_members m on m.ns = h.ns
--   left join auth.users u on u.id = m.user_id
--   order by h.ns, m.name;
-- ════════════════════════════════════════════════════════════════════


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
