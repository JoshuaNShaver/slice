-- Each account's saves, written only by the game server (design logs 0097,
-- 0114). RLS is on with no policies, and anon/authenticated have no grants,
-- so only the server's secret key (service_role) can read or write them.

create table public.families (
	user_id uuid not null references auth.users (id) on delete cascade,
	slot smallint not null check (slot between 0 and 2),
	data jsonb not null,  -- Family.to_dict()
	updated_at timestamptz not null default now(),
	primary key (user_id, slot)
);

create table public.chests (
	user_id uuid primary key references auth.users (id) on delete cascade,
	items jsonb not null default '[]'::jsonb,  -- item strings, "" for empty
	updated_at timestamptz not null default now()
);

alter table public.families enable row level security;
alter table public.chests enable row level security;

revoke all on table public.families from anon, authenticated;
revoke all on table public.chests from anon, authenticated;
grant select, insert, update, delete on table public.families to service_role;
grant select, insert, update, delete on table public.chests to service_role;
