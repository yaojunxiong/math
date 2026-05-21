-- Multiplication Trainer Supabase schema
-- Shared auth: auth.users
-- Shared profile table: profiles
-- Math tables are prefixed with math_

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  avatar_url text,
  role text not null default 'student', -- student / admin
  locale text not null default 'zh',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.math_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  guest_user_id text,
  guest_user_name text,
  device_fingerprint text not null,
  user_agent text,
  language text,
  platform text,
  screen_width int,
  screen_height int,
  timezone text,
  last_seen_at timestamptz default now(),
  created_at timestamptz default now(),
  unique(device_fingerprint)
);

create table if not exists public.math_test_results (
  id bigserial primary key,
  user_id uuid references auth.users(id) on delete set null,
  guest_user_id text,
  guest_user_name text,
  device_id uuid references public.math_devices(id) on delete set null,
  mode text not null,
  total_questions int not null default 45,
  correct_count int not null default 0,
  accuracy int not null default 0,
  total_seconds int not null default 0,
  avg_seconds numeric(6,2) not null default 0,
  wrong_count int not null default 0,
  locale text not null default 'zh',
  details jsonb,
  is_deleted boolean not null default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.math_mistake_facts (
  id bigserial primary key,
  user_id uuid references auth.users(id) on delete cascade,
  guest_user_id text,
  guest_user_name text,
  device_id uuid references public.math_devices(id) on delete set null,
  a int not null,
  b int not null,
  answer int not null,
  wrong_count int not null default 0,
  slow_count int not null default 0,
  right_streak int not null default 0,
  is_resolved boolean not null default false,
  updated_at timestamptz default now(),
  created_at timestamptz default now()
);

create unique index if not exists uniq_math_mistake_user_fact
on public.math_mistake_facts (user_id, a, b)
where user_id is not null;

create unique index if not exists uniq_math_mistake_guest_fact
on public.math_mistake_facts (guest_user_id, device_id, a, b)
where user_id is null and guest_user_id is not null and device_id is not null;

alter table public.profiles enable row level security;
alter table public.math_devices enable row level security;
alter table public.math_test_results enable row level security;
alter table public.math_mistake_facts enable row level security;

-- Profiles
create policy if not exists "profiles read authenticated" on public.profiles for select to authenticated using (true);
create policy if not exists "profiles insert own" on public.profiles for insert to authenticated with check (auth.uid() = id);
create policy if not exists "profiles update own" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- Devices: allow inserts from both anon and authenticated so guest devices can be stored.
create policy if not exists "math_devices insert all" on public.math_devices for insert to anon, authenticated with check (true);
create policy if not exists "math_devices update all" on public.math_devices for update to anon, authenticated using (true) with check (true);
create policy if not exists "math_devices read authenticated" on public.math_devices for select to authenticated using (true);

-- Test results: guests can insert; authenticated can insert/read. Admin UI reads as authenticated.
create policy if not exists "math_test_results insert all" on public.math_test_results for insert to anon, authenticated with check (true);
create policy if not exists "math_test_results read authenticated" on public.math_test_results for select to authenticated using (true);
create policy if not exists "math_test_results update authenticated" on public.math_test_results for update to authenticated using (true) with check (true);

-- Mistakes: guests can insert/update their current records; authenticated can read for admin/own display.
create policy if not exists "math_mistakes insert all" on public.math_mistake_facts for insert to anon, authenticated with check (true);
create policy if not exists "math_mistakes update all" on public.math_mistake_facts for update to anon, authenticated using (true) with check (true);
create policy if not exists "math_mistakes read authenticated" on public.math_mistake_facts for select to authenticated using (true);

create index if not exists idx_math_results_rank on public.math_test_results (is_deleted, accuracy desc, correct_count desc, total_seconds asc, avg_seconds asc);
create index if not exists idx_math_results_user_created on public.math_test_results (user_id, created_at desc);
create index if not exists idx_math_results_guest_created on public.math_test_results (guest_user_id, created_at desc);
create index if not exists idx_math_mistakes_user on public.math_mistake_facts (user_id, updated_at desc);
create index if not exists idx_math_mistakes_guest on public.math_mistake_facts (guest_user_id, device_id, updated_at desc);
