-- Each account's quest progress (design log 0183): the player's, kept
-- across families, so a new family carries on the plot. PlayerQuests'
-- save: quest id -> {"step", "counts"}. Written only by the game server,
-- like the saves (0114).

create table public.quests (
	user_id uuid primary key references auth.users (id) on delete cascade,
	progress jsonb not null default '{}'::jsonb,
	updated_at timestamptz not null default now()
);

alter table public.quests enable row level security;

revoke all on table public.quests from anon, authenticated;
grant select, insert, update, delete on table public.quests to service_role;
