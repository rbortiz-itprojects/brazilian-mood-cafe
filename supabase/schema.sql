-- ============================================================
-- Brazilian Cafe Ordering App — Supabase Schema
-- Run this in the Supabase SQL editor (Project > SQL Editor)
-- ============================================================

-- ---------- Extensions ----------
create extension if not exists "pgcrypto";

-- ---------- Tables (the restaurant's physical tables) ----------
create table if not exists public.tables (
  id uuid primary key default gen_random_uuid(),
  number int not null unique,
  qr_token text not null unique default encode(gen_random_bytes(8), 'hex'),
  active boolean not null default true
);

-- ---------- Menu categories ----------
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sort_order int not null default 0,
  active boolean not null default true
);

-- ---------- Menu items ----------
create table if not exists public.menu_items (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories(id) on delete cascade,
  name text not null,
  description text default '',
  price_cents int not null check (price_cents >= 0),
  image_url text default '',
  notes text default '',            -- e.g. "contains nuts", "vegan option available"
  active boolean not null default true,
  sort_order int not null default 0,
  -- future Square sync
  square_item_id text,
  updated_at timestamptz not null default now()
);

-- ---------- Orders ----------
create type order_status as enum ('new', 'in_preparation', 'done', 'cancelled');

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  table_number int not null,
  customer_name text not null,
  customer_phone text,              -- optional, E.164 format e.g. +614xxxxxxxx
  sms_opt_in boolean not null default false,
  status order_status not null default 'new',
  total_cents int not null default 0,
  created_at timestamptz not null default now(),
  started_at timestamptz,           -- set when kitchen marks "in preparation"
  done_at timestamptz               -- set when kitchen marks "done"
);

-- ---------- Order line items ----------
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  menu_item_id uuid references public.menu_items(id),
  name_snapshot text not null,      -- captured at order time so menu edits don't rewrite history
  price_cents_snapshot int not null,
  quantity int not null default 1,
  notes text default ''             -- customer note, e.g. "no sugar", "extra guaraná"
);

-- ---------- Seed: a few tables ----------
insert into public.tables (number) values (1),(2),(3),(4),(5)
  on conflict (number) do nothing;

-- ---------- Seed: categories ----------
insert into public.categories (name, sort_order) values
  ('Salgados', 1),
  ('Doces', 2),
  ('Bebidas', 3)
on conflict do nothing;

-- ---------- Seed: menu items ----------
with cat as (select id, name from public.categories)
insert into public.menu_items (category_id, name, description, price_cents, image_url, notes, sort_order)
select cat.id, v.name, v.description, v.price_cents, v.image_url, v.notes, v.sort_order
from (values
  ('Salgados','Coxinha de Frango','Shredded chicken, shaped like a drumstick, fried until golden',700,'https://images.unsplash.com/photo-1626082927389-6cd097cee6a6?w=600','Contains gluten',1),
  ('Salgados','Pão de Queijo (6un)','Warm Brazilian cheese bread, naturally gluten-free',900,'https://images.unsplash.com/photo-1619894991209-9f9694be045b?w=600','Gluten-free',2),
  ('Salgados','Pastel de Carne','Crispy fried pastry filled with seasoned beef',800,'https://images.unsplash.com/photo-1625944230945-1b7dd3b949ab?w=600','',3),
  ('Doces','Brigadeiro (3un)','Classic chocolate fudge balls rolled in sprinkles',600,'https://images.unsplash.com/photo-1481391319762-47dff72954d9?w=600','Contains dairy',1),
  ('Doces','Bolo de Fubá','Traditional Brazilian cornmeal cake',650,'https://images.unsplash.com/photo-1509365465985-25d11c17e812?w=600','',2),
  ('Bebidas','Guaraná Antarctica','Brazilian soft drink, 350ml can',500,'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=600','',1),
  ('Bebidas','Café Coado','Traditional Brazilian filtered coffee',450,'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600','',2),
  ('Bebidas','Suco de Maracujá','Fresh passionfruit juice',700,'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=600','',3)
) as v(cat_name, name, description, price_cents, image_url, notes, sort_order)
join cat on cat.name = v.cat_name;

-- ============================================================
-- Row Level Security
-- ============================================================
alter table public.tables enable row level security;
alter table public.categories enable row level security;
alter table public.menu_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Public (anon) can read active tables/categories/menu items
create policy "public read tables" on public.tables for select using (active = true);
create policy "public read categories" on public.categories for select using (active = true);
create policy "public read menu_items" on public.menu_items for select using (active = true);

-- Public (anon) can create orders + order items (customer checkout), and read/update them
-- (kitchen dashboard also runs as anon in this scaffold — see README for locking this down further)
create policy "public insert orders" on public.orders for insert with check (true);
create policy "public read orders" on public.orders for select using (true);
create policy "public update orders" on public.orders for update using (true);

create policy "public insert order_items" on public.order_items for insert with check (true);
create policy "public read order_items" on public.order_items for select using (true);

-- Admin (authenticated Supabase Auth users only) can manage the menu
create policy "admin manage categories" on public.categories for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "admin manage menu_items" on public.menu_items for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "admin manage tables" on public.tables for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- ---------- Realtime ----------
alter publication supabase_realtime add table public.orders;
alter publication supabase_realtime add table public.order_items;
