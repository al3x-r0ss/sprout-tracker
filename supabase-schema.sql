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

-- ============================================================
-- Friends system (gamified-only visibility — no dollar amounts
-- are ever exposed to friends, only level/streak/goal % stats)
-- ============================================================

-- A lightweight public profile row per user, created automatically on signup.
-- Only stores id + email — needed so people can find each other to add as friends.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email) values (new.id, lower(new.email))
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Backfill profiles for any account created before this trigger existed.
insert into public.profiles (id, email)
select id, lower(email) from auth.users
on conflict (id) do nothing;

alter table public.profiles enable row level security;

-- Emails are ONLY visible to yourself or to someone you're already connected
-- to via a friendship row (pending, accepted, or declined) — never browsable
-- by every signed-in user.
drop policy if exists "Authenticated users can view profiles" on public.profiles;
drop policy if exists "View own or connected profiles" on public.profiles;
create policy "View own or connected profiles"
  on public.profiles for select
  using (
    auth.uid() = id
    or exists (
      select 1 from public.friendships f
      where (f.requester_id = auth.uid() and f.addressee_id = profiles.id)
         or (f.addressee_id = auth.uid() and f.requester_id = profiles.id)
    )
  );

-- Narrow lookup used only to resolve "add friend by email" to a user id.
-- Returns nothing but a uuid (or null) — never exposes the profiles list itself.
create or replace function public.find_user_id_by_email(lookup_email text)
returns uuid
language sql
security definer
set search_path = public
as $$
  select id from public.profiles where email = lower(lookup_email) limit 1;
$$;
revoke all on function public.find_user_id_by_email(text) from public;
grant execute on function public.find_user_id_by_email(text) to authenticated;

-- Friend requests / friendships
create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  addressee_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined')),
  created_at timestamptz not null default now(),
  unique (requester_id, addressee_id)
);
create index if not exists friendships_requester_idx on public.friendships(requester_id);
create index if not exists friendships_addressee_idx on public.friendships(addressee_id);

alter table public.friendships enable row level security;

drop policy if exists "View own friendships" on public.friendships;
create policy "View own friendships"
  on public.friendships for select
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

drop policy if exists "Create friend request" on public.friendships;
create policy "Create friend request"
  on public.friendships for insert
  with check (auth.uid() = requester_id);

drop policy if exists "Respond to friend request" on public.friendships;
create policy "Respond to friend request"
  on public.friendships for update
  using (auth.uid() = addressee_id)
  with check (auth.uid() = addressee_id);

drop policy if exists "Remove friendship" on public.friendships;
create policy "Remove friendship"
  on public.friendships for delete
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

-- Gamified public stats — deliberately contains NO dollar amounts,
-- only level, badge, streaks, entry count, and goal completion counts.
create table if not exists public.public_stats (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  level int not null default 1,
  badge text not null default '🌱',
  current_streak int not null default 0,
  longest_streak int not null default 0,
  goals_total int not null default 0,
  goals_completed int not null default 0,
  total_entries int not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.public_stats enable row level security;

drop policy if exists "Users manage own stats" on public.public_stats;
create policy "Users manage own stats"
  on public.public_stats for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Friends can view stats" on public.public_stats;
create policy "Friends can view stats"
  on public.public_stats for select
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
        and (
          (f.requester_id = auth.uid() and f.addressee_id = public_stats.user_id)
          or (f.addressee_id = auth.uid() and f.requester_id = public_stats.user_id)
        )
    )
  );
