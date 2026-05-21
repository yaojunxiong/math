-- Multiplication Trainer Supabase schema
-- Run in Supabase SQL Editor.
-- Shared auth: auth.users
-- Shared profile table: profiles
-- Math-specific tables are prefixed with math_
-- Shared site analytics table: site_visit_logs, used by math and TypingJapaneseWords.

create extension if not exists pgcrypto;

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
  device_fingerprint text not null unique,
  user_agent text,
  language text,
  platform text,
  screen_width int,
  screen_height int,
  timezone text,
  last_seen_at timestamptz default now(),
  created_at timestamptz default now()
);

-- Shared website access log. Use site_code='math' for this project and site_code='minna' for TypingJapaneseWords.
create table if not exists public.site_visit_logs (
  id bigserial primary key,
  site_code text not null,
  site_name text,
  page_url text not null,
  page_path text,
  page_title text,
  referrer text,
  user_id uuid references auth.users(id) on delete set null,
  guest_user_id text,
  guest_user_name text,
  device_id uuid references public.math_devices(id) on delete set null,
  device_fingerprint text,
  session_id text,
  user_agent text,
  language text,
  platform text,
  screen_width int,
  screen_height int,
  timezone text,
  locale text default 'zh',
  extra jsonb,
  visited_at timestamptz default now(),
  created_at timestamptz default now()
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
alter table public.site_visit_logs enable row level security;
alter table public.math_test_results enable row level security;
alter table public.math_mistake_facts enable row level security;

-- Profiles policies
DROP POLICY IF EXISTS "profiles read authenticated" ON public.profiles;
CREATE POLICY "profiles read authenticated" ON public.profiles FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "profiles insert own" ON public.profiles;
CREATE POLICY "profiles insert own" ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
DROP POLICY IF EXISTS "profiles update own" ON public.profiles;
CREATE POLICY "profiles update own" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Devices policies: allow guest device registration; authenticated users can inspect devices for admin page.
DROP POLICY IF EXISTS "math_devices insert all" ON public.math_devices;
CREATE POLICY "math_devices insert all" ON public.math_devices FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "math_devices update all" ON public.math_devices;
CREATE POLICY "math_devices update all" ON public.math_devices FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "math_devices read authenticated" ON public.math_devices;
CREATE POLICY "math_devices read authenticated" ON public.math_devices FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "math_devices read anon own" ON public.math_devices;
CREATE POLICY "math_devices read anon own" ON public.math_devices FOR SELECT TO anon USING (true);

-- Shared visit log policies
DROP POLICY IF EXISTS "site_visit_logs insert all" ON public.site_visit_logs;
CREATE POLICY "site_visit_logs insert all" ON public.site_visit_logs FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "site_visit_logs read authenticated" ON public.site_visit_logs;
CREATE POLICY "site_visit_logs read authenticated" ON public.site_visit_logs FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "site_visit_logs update authenticated" ON public.site_visit_logs;
CREATE POLICY "site_visit_logs update authenticated" ON public.site_visit_logs FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- Test results policies
DROP POLICY IF EXISTS "math_test_results insert all" ON public.math_test_results;
CREATE POLICY "math_test_results insert all" ON public.math_test_results FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "math_test_results read authenticated" ON public.math_test_results;
CREATE POLICY "math_test_results read authenticated" ON public.math_test_results FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "math_test_results read anon" ON public.math_test_results;
CREATE POLICY "math_test_results read anon" ON public.math_test_results FOR SELECT TO anon USING (true);
DROP POLICY IF EXISTS "math_test_results update authenticated" ON public.math_test_results;
CREATE POLICY "math_test_results update authenticated" ON public.math_test_results FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- Mistakes policies
DROP POLICY IF EXISTS "math_mistakes insert all" ON public.math_mistake_facts;
CREATE POLICY "math_mistakes insert all" ON public.math_mistake_facts FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "math_mistakes update all" ON public.math_mistake_facts;
CREATE POLICY "math_mistakes update all" ON public.math_mistake_facts FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "math_mistakes read authenticated" ON public.math_mistake_facts;
CREATE POLICY "math_mistakes read authenticated" ON public.math_mistake_facts FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "math_mistakes read anon" ON public.math_mistake_facts;
CREATE POLICY "math_mistakes read anon" ON public.math_mistake_facts FOR SELECT TO anon USING (true);

create index if not exists idx_site_visit_logs_site_time on public.site_visit_logs (site_code, visited_at desc);
create index if not exists idx_site_visit_logs_user_time on public.site_visit_logs (user_id, visited_at desc);
create index if not exists idx_site_visit_logs_guest_time on public.site_visit_logs (guest_user_id, visited_at desc);
create index if not exists idx_site_visit_logs_device_time on public.site_visit_logs (device_fingerprint, visited_at desc);
create index if not exists idx_math_results_rank on public.math_test_results (is_deleted, accuracy desc, correct_count desc, total_seconds asc, avg_seconds asc);
create index if not exists idx_math_results_user_created on public.math_test_results (user_id, created_at desc);
create index if not exists idx_math_results_guest_created on public.math_test_results (guest_user_id, created_at desc);
create index if not exists idx_math_mistakes_user on public.math_mistake_facts (user_id, updated_at desc);
create index if not exists idx_math_mistakes_guest on public.math_mistake_facts (guest_user_id, device_id, updated_at desc);
