-- Each account's public name (design log 0123). Players see usernames,
-- never emails. Written only by the game server, like the saves (0114).

create table public.profiles (
	user_id uuid primary key references auth.users (id) on delete cascade,
	username text not null check (username ~ '^[A-Za-z0-9_]{3,16}$'),
	created_at timestamptz not null default now()
);

-- Unique ignoring case: "Square" and "square" are the same name.
create unique index profiles_username_lower on public.profiles (lower(username));

alter table public.profiles enable row level security;

revoke all on table public.profiles from anon, authenticated;
grant select, insert, update, delete on table public.profiles to service_role;
