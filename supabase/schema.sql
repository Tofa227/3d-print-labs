-- TOFA3D Studio: схема базы для Supabase.
-- Запускать один раз: Supabase → SQL Editor → New query → вставить весь файл → Run.
-- Потом так же запустить seed.sql (стартовые товары, материалы, цвета, доставка, купоны).

-- ============ Профили покупателей ============
create table if not exists public.profiles (
  id          uuid primary key references auth.users on delete cascade,
  name        text not null default '',
  email       text,
  phone       jsonb,                 -- {cc:'hu', digits:'201234567', text:'+36 20 123 4567'}
  addr        jsonb,                 -- {delivery:'home', text:'...'}
  role        text not null default 'customer' check (role in ('customer','admin')),
  wallet      text[] not null default '{}',   -- купоны, которые покупатель добавил себе
  created_at  timestamptz not null default now()
);
alter table public.profiles add column if not exists wallet text[] not null default '{}';

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- Профиль создаётся автоматически при регистрации.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name, email, phone)
  values (new.id,
          left(coalesce(new.raw_user_meta_data->>'name', new.raw_user_meta_data->>'full_name',
                        new.raw_user_meta_data->>'user_name', split_part(coalesce(new.email, ''), '@', 1), ''), 100),
          new.email,
          case when pg_column_size(new.raw_user_meta_data->'phone') < 400 then new.raw_user_meta_data->'phone' end)
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Покупатель не может сам сделать себя админом.
-- Из SQL Editor (auth.uid() пустой) роль менять можно: так назначается первый админ.
create or replace function public.protect_role() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role and auth.uid() is not null and not public.is_admin() then
    raise exception 'role change not allowed';
  end if;
  return new;
end $$;

drop trigger if exists profiles_protect_role on public.profiles;
create trigger profiles_protect_role before update on public.profiles
  for each row execute function public.protect_role();

-- ============ Каталог ============
create table if not exists public.categories (
  id    text primary key,
  name  jsonb not null,              -- {hu, en, ru}
  sort  int not null default 0
);

create table if not exists public.materials (
  id    text primary key,            -- 'PLA', 'PETG' ...
  pct   numeric not null default 0,  -- наценка, %
  s     int not null default 3,      -- прочность 1–5
  h     int not null default 1,      -- термостойкость 1–5
  f     int not null default 1,      -- гибкость 1–5
  temp  int not null default 0,      -- рабочая температура, °C
  use   jsonb not null default '{}',
  sort  int not null default 0
);

create table if not exists public.colors (
  id    text primary key,
  hex   text not null,
  name  jsonb not null,
  sort  int not null default 0
);

create table if not exists public.products (
  id          text primary key,
  shape       text,                  -- 3D-превью из встроенных форм
  cat         text references public.categories on update cascade on delete set null,
  price       int not null check (price >= 0),   -- Ft, для материала с наценкой 0 %
  name        jsonb not null,
  descr       jsonb not null default '{}',
  active      boolean not null default true,
  photo       text not null default '',   -- старое поле (одно фото в base64), заменено на photos
  photos      jsonb not null default '[]',  -- [{u: полное фото, t: миниатюра, k: путь в Storage}]
  mats        text[],                -- пусто = все материалы
  colors      text[],                -- пусто = все цвета
  sort        int not null default 0,
  created_at  timestamptz not null default now()
);

alter table public.products add column if not exists photos jsonb not null default '[]';

create table if not exists public.delivery (
  id       text primary key,
  type     text not null check (type in ('pickup','point','home')),
  enabled  boolean not null default true,
  fee      int not null default 0,
  name     jsonb not null,
  sort     int not null default 0
);

create table if not exists public.coupons (
  code           text primary key,
  type           text not null check (type in ('percent','fixed')),
  value          int not null check (value > 0),
  min            int not null default 0,
  expires        date,
  max_uses       int not null default 0,     -- 0 = без лимита
  used           int not null default 0,
  once_per_user  boolean not null default true,
  active         boolean not null default true,
  "grant"        boolean not null default false  -- показывать в кабинете каждому покупателю
);

create table if not exists public.settings (
  id    int primary key default 1 check (id = 1),
  data  jsonb not null default '{}'
);

-- ============ Заказы ============
create table if not exists public.orders (
  ref         text primary key,
  user_id     uuid references auth.users on delete set null,
  created_at  timestamptz not null default now(),
  name        text not null,
  phone       jsonb not null,
  mail        text not null default '',
  tg          text not null default '',
  note        text not null default '',
  addr        text not null default '',
  delivery    jsonb not null,        -- {id, type, name, fee}
  items       jsonb not null,        -- [{pid, name, mat, color, qty, unit}]
  subtotal    int not null,
  discount    int not null default 0,
  coupon      jsonb,                 -- {code, discount}
  total       int not null,
  status      text not null default 'new'
              check (status in ('new','confirmed','printing','ready','shipped','done','cancelled')),
  history     jsonb not null default '[]',
  inote       text not null default ''   -- внутренняя заметка админа
);
create index if not exists orders_user_idx on public.orders (user_id, created_at desc);
create index if not exists orders_created_idx on public.orders (created_at desc);

-- Внутренние заметки админа к заказам: отдельная таблица, покупатель их не видит.
create table if not exists public.order_notes (
  ref   text primary key references public.orders on delete cascade on update cascade,
  note  text not null default '' check (char_length(note) <= 5000)
);
insert into public.order_notes (ref, note)
  select ref, inote from public.orders where inote <> '' on conflict (ref) do nothing;
update public.orders set inote = '' where inote <> '';

-- Ограничения размеров, чтобы в базу нельзя было записать мусор огромного объёма.
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_size_chk') then
    alter table public.profiles add constraint profiles_size_chk check (
      char_length(name) <= 100 and pg_column_size(phone) < 400 and pg_column_size(addr) < 2000
      and cardinality(wallet) <= 50);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'products_photo_chk') then
    alter table public.products add constraint products_photo_chk check (char_length(photo) < 1500000);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'products_photos_chk') then
    alter table public.products add constraint products_photos_chk check (jsonb_typeof(photos) = 'array' and jsonb_array_length(photos) <= 12 and pg_column_size(photos) < 20000);
  end if;
end $$;

-- ============ Права доступа (RLS) ============
alter table public.profiles   enable row level security;
alter table public.categories enable row level security;
alter table public.materials  enable row level security;
alter table public.colors     enable row level security;
alter table public.products   enable row level security;
alter table public.delivery   enable row level security;
alter table public.coupons    enable row level security;
alter table public.settings   enable row level security;
alter table public.orders     enable row level security;
alter table public.order_notes enable row level security;

-- Профили: каждый видит и правит свой, админ видит и правит всех.
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select using (id = auth.uid() or public.is_admin());
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update using (id = auth.uid() or public.is_admin());

-- Каталог читают все, меняет только админ.
do $$
declare t text;
begin
  foreach t in array array['categories','materials','colors','delivery','settings'] loop
    execute format('drop policy if exists %1$s_read on public.%1$s', t);
    execute format('create policy %1$s_read on public.%1$s for select using (true)', t);
    execute format('drop policy if exists %1$s_admin on public.%1$s', t);
    execute format('create policy %1$s_admin on public.%1$s for all using (public.is_admin()) with check (public.is_admin())', t);
  end loop;
end $$;

-- Товары: скрытые видит только админ.
drop policy if exists products_read on public.products;
create policy products_read on public.products for select using (active or public.is_admin());
drop policy if exists products_admin on public.products;
create policy products_admin on public.products for all using (public.is_admin()) with check (public.is_admin());

-- Купоны: список целиком видит только админ; покупатель видит лишь «подарочные» (grant).
-- Остальные коды проверяются функцией check_coupon и наружу не утекают.
drop policy if exists coupons_grant on public.coupons;
create policy coupons_grant on public.coupons for select using ("grant" and active and auth.uid() is not null);
drop policy if exists coupons_admin on public.coupons;
create policy coupons_admin on public.coupons for all using (public.is_admin()) with check (public.is_admin());

-- Заказы: покупатель видит свои; админ видит и меняет все.
-- Создавать заказ напрямую нельзя: только через place_order(), которая сама считает цены.
drop policy if exists orders_read on public.orders;
create policy orders_read on public.orders for select using (user_id = auth.uid() or public.is_admin());
drop policy if exists orders_admin on public.orders;
create policy orders_admin on public.orders for update using (public.is_admin()) with check (public.is_admin());
drop policy if exists orders_admin_del on public.orders;
create policy orders_admin_del on public.orders for delete using (public.is_admin());
drop policy if exists order_notes_admin on public.order_notes;
create policy order_notes_admin on public.order_notes for all using (public.is_admin()) with check (public.is_admin());

-- ============ Проверка купона ============
-- Возвращает {ok:true, code, discount} или {ok:false, key, v}; ключи совпадают с переводами на сайте.
create or replace function public.check_coupon(p_code text, p_subtotal int)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare c public.coupons; d int;
begin
  select * into c from public.coupons where code = upper(trim(coalesce(p_code, '')));
  if not found or not c.active then return jsonb_build_object('ok', false, 'key', 'cp_invalid'); end if;
  if c.expires is not null and c.expires < (now() at time zone 'Europe/Budapest')::date then
    return jsonb_build_object('ok', false, 'key', 'cp_expired_m'); end if;
  if c.max_uses > 0 and c.used >= c.max_uses then return jsonb_build_object('ok', false, 'key', 'cp_limit'); end if;
  if p_subtotal < c.min then return jsonb_build_object('ok', false, 'key', 'cp_min_m', 'v', c.min); end if;
  if c.once_per_user then
    if auth.uid() is null then return jsonb_build_object('ok', false, 'key', 'cp_login_m'); end if;
    if exists (select 1 from public.orders o where o.user_id = auth.uid()
               and o.coupon->>'code' = c.code and o.status <> 'cancelled') then
      return jsonb_build_object('ok', false, 'key', 'cp_used_m'); end if;
  end if;
  d := case when c.type = 'percent' then round(p_subtotal * c.value / 100.0)::int else least(p_subtotal, c.value) end;
  return jsonb_build_object('ok', true, 'code', c.code, 'discount', d, 'type', c.type, 'value', c.value, 'min', c.min);
end $$;

-- ============ Оформление заказа ============
-- p = {items:[{pid,mat,color,qty}], delivery:'tab', coupon:'WELCOME10',
--      name, phone:{cc,num,text}, mail, tg, note, addr}
-- Цены, скидка и доставка считаются здесь, а не в браузере.
create or replace function public.place_order(p jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  it jsonb; pr public.products; m public.materials; dl public.delivery;
  items jsonb := '[]'; sub int := 0; unit int; q int;
  cp jsonb; disc int := 0; ref text; o public.orders;
  v_name text := left(trim(coalesce(p->>'name', '')), 100);
  v_digits text := regexp_replace(coalesce(p->'phone'->>'digits', p->'phone'->>'num', ''), '\D', '', 'g');
  v_addr text := trim(coalesce(p->>'addr', ''));
begin
  if length(v_name) < 2 then raise exception 'e_name'; end if;
  if p->'phone' is null or length(v_digits) <> 9 or pg_column_size(p->'phone') > 400 then
    raise exception 'e_phone'; end if;
  -- Защита от спама: не больше 5 заказов с одного телефона в час и 30 заказов на весь магазин за 10 минут.
  if (select count(*) from public.orders where created_at > now() - interval '10 minutes') >= 30
     or (select count(*) from public.orders where created_at > now() - interval '1 hour'
           and regexp_replace(coalesce(phone->>'digits', phone->>'num', ''), '\D', '', 'g') = v_digits) >= 5 then
    raise exception 'rate_limit'; end if;
  if jsonb_typeof(p->'items') <> 'array' or jsonb_array_length(p->'items') = 0 then raise exception 'empty'; end if;
  if jsonb_array_length(p->'items') > 50 then raise exception 'too_many'; end if;

  select * into dl from public.delivery where id = p->>'delivery' and enabled;
  if not found then raise exception 'bad_delivery'; end if;
  if dl.type <> 'pickup' and v_addr = '' then raise exception 'e_addr'; end if;

  for it in select * from jsonb_array_elements(p->'items') loop
    select * into pr from public.products where id = it->>'pid' and active;
    if not found then raise exception 'bad_product %', it->>'pid'; end if;
    select * into m from public.materials where id = it->>'mat';
    if not found or (coalesce(cardinality(pr.mats), 0) > 0 and not (m.id = any(pr.mats))) then
      raise exception 'bad_material %', it->>'mat'; end if;
    if not exists (select 1 from public.colors where id = it->>'color')
       or (coalesce(cardinality(pr.colors), 0) > 0 and not ((it->>'color') = any(pr.colors))) then
      raise exception 'bad_color %', it->>'color'; end if;
    q := (it->>'qty')::int;
    if q is null or q < 1 or q > 500 then raise exception 'bad_qty'; end if;
    unit := round(pr.price * (1 + m.pct / 100.0))::int;
    sub := sub + unit * q;
    items := items || jsonb_build_object('pid', pr.id, 'name', pr.name, 'mat', m.id,
                                         'color', it->>'color', 'qty', q, 'unit', unit);
  end loop;

  if coalesce(trim(p->>'coupon'), '') <> '' then
    cp := public.check_coupon(p->>'coupon', sub);
    if not (cp->>'ok')::boolean then raise exception 'coupon:%', cp->>'key'; end if;
    disc := (cp->>'discount')::int;
    update public.coupons set used = used + 1 where code = cp->>'code';
  end if;

  ref := 'TF-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  insert into public.orders (ref, user_id, name, phone, mail, tg, note, addr, delivery, items,
                             subtotal, discount, coupon, total, history)
  values (ref, auth.uid(), v_name, p->'phone',
          left(trim(coalesce(p->>'mail', '')), 200), left(trim(coalesce(p->>'tg', '')), 100),
          left(trim(coalesce(p->>'note', '')), 2000), left(v_addr, 500),
          jsonb_build_object('id', dl.id, 'type', dl.type, 'name', dl.name, 'fee', dl.fee),
          items, sub, disc,
          case when cp is null then null else jsonb_build_object('code', cp->>'code', 'discount', disc) end,
          greatest(0, sub - disc) + dl.fee,
          jsonb_build_array(jsonb_build_object('status', 'new', 'ts', (extract(epoch from now()) * 1000)::bigint)))
  returning * into o;

  if auth.uid() is not null then
    update public.profiles
       set addr = jsonb_build_object('delivery', dl.id,
                                     'text', case when v_addr <> '' then v_addr else coalesce(addr->>'text', '') end)
     where id = auth.uid();
  end if;

  return to_jsonb(o);
end $$;

-- Смена статуса заказа админом с записью в историю.
create or replace function public.set_order_status(p_ref text, p_status text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  update public.orders
     set status = p_status,
         history = history || jsonb_build_array(jsonb_build_object('status', p_status, 'ts', (extract(epoch from now()) * 1000)::bigint))
   where ref = p_ref;
end $$;

-- Купоны покупателя: добавленные им коды + «подарочные» (grant).
create or replace function public.my_coupons()
returns setof public.coupons language sql stable security definer set search_path = public as $$
  select c.* from public.coupons c
   where auth.uid() is not null
     and (c.code = any (coalesce((select wallet from public.profiles where id = auth.uid()), '{}'))
          or (c."grant" and c.active));
$$;

-- Добавить купон в кабинет по коду.
create or replace function public.add_coupon(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare c public.coupons;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'key', 'cp_login_m'); end if;
  select * into c from public.coupons where code = upper(trim(coalesce(p_code, '')));
  if not found or not c.active then return jsonb_build_object('ok', false, 'key', 'cp_invalid'); end if;
  if c.expires is not null and c.expires < (now() at time zone 'Europe/Budapest')::date then
    return jsonb_build_object('ok', false, 'key', 'cp_expired_m'); end if;
  update public.profiles set wallet = array_append(wallet, c.code)
   where id = auth.uid() and not (c.code = any (wallet));
  return jsonb_build_object('ok', true, 'code', c.code);
end $$;

-- Явные права для API (работает и при выключенном «Automatically expose new tables»).
-- Что именно можно делать со строками, всё равно решают политики RLS выше.
grant usage on schema public to anon, authenticated;
grant select on public.categories, public.materials, public.colors, public.products,
               public.delivery, public.settings to anon, authenticated;
grant insert, update, delete on public.categories, public.materials, public.colors, public.products,
               public.delivery, public.settings, public.coupons to authenticated;
grant select on public.coupons, public.orders, public.profiles to authenticated;
grant update on public.profiles, public.orders to authenticated;
grant delete on public.orders to authenticated;
grant select, insert, update, delete on public.order_notes to authenticated;

revoke all on function public.place_order(jsonb) from public;
grant execute on function public.place_order(jsonb) to anon, authenticated;
grant execute on function public.check_coupon(text, int) to anon, authenticated;
grant execute on function public.set_order_status(text, text) to authenticated;
grant execute on function public.is_admin() to anon, authenticated;
grant execute on function public.my_coupons() to authenticated;
grant execute on function public.add_coupon(text) to authenticated;

-- ============ Фото товаров (Supabase Storage) ============
-- Публичная корзина «products»: смотреть фото может любой, загружать и удалять только админ.
do $$
begin
  if exists (select 1 from information_schema.schemata where schema_name = 'storage') then
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values ('products', 'products', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
    on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

    drop policy if exists products_img_read on storage.objects;
    create policy products_img_read on storage.objects for select using (bucket_id = 'products');
    drop policy if exists products_img_insert on storage.objects;
    create policy products_img_insert on storage.objects for insert to authenticated with check (bucket_id = 'products' and public.is_admin());
    drop policy if exists products_img_update on storage.objects;
    create policy products_img_update on storage.objects for update to authenticated using (bucket_id = 'products' and public.is_admin());
    drop policy if exists products_img_delete on storage.objects;
    create policy products_img_delete on storage.objects for delete to authenticated using (bucket_id = 'products' and public.is_admin());
  end if;
end $$;
