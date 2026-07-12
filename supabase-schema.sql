-- ============================================================
-- Sprout — Supabase schema
-- Run this in your Supabase project: SQL Editor → New Query → Run
-- ============================================================

-- Entries: every deposit/contribution you log
create table if not exists public.entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (category in ('savings','investments','income','other')),
  amount numeric not null,
  entry_date date not null default current_date,
  note text,
  created_at timestamptz not null default now()
);

-- Goals: savings targets with progress tracking
create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  target_amount numeric not null check (target_amount > 0),
  emoji text default '🎯',
  created_at timestamptz not null default now()
);

-- Helpful indexes
create index if not exists entries_user_id_idx on public.entries(user_id);
create index if not exists entries_date_idx on public.entries(entry_date);
create index if not exists goals_user_id_idx on public.goals(user_id);

-- ============================================================
-- Row Level Security — each user can only ever see/edit their own rows
-- ============================================================
alter table public.entries enable row level security;
alter table public.goals enable row level security;

drop policy if exists "Users manage own entries" on public.entries;
create policy "Users manage own entries"
  on public.entries
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users manage own goals" on public.goals;
create policy "Users manage own goals"
  on public.goals
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
