-- What each account has unlocked, kept across families (design log 0174):
-- names such as "irregular" (founding an irregular family). Written only by
-- the game server, like the saves (0114).

create table public.unlocks (
	user_id uuid primary key references auth.users (id) on delete cascade,
	names jsonb not null default '[]'::jsonb,
	updated_at timestamptz not null default now()
);

alter table public.unlocks enable row level security;

revoke all on table public.unlocks from anon, authenticated;
grant select, insert, update, delete on table public.unlocks to service_role;
