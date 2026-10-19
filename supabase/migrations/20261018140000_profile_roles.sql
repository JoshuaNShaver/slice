-- Admins (design log 0125). An admin can run \ commands in the game's chat.
-- Only a database update makes one: the game server never writes this
-- column, and players can't reach the table (RLS on, no grants; 0123).
--
--   update public.profiles set role = 'admin' where username = 'SomeName';

alter table public.profiles
	add column role text not null default 'player'
	check (role in ('player', 'admin'));
