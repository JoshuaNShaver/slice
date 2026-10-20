-- The roles allowed in profiles.role, as in 20261019120000. Repeating the
-- check changes nothing; this migration has already run on the online
-- database, so it stays.

alter table public.profiles drop constraint profiles_role_check;
alter table public.profiles
	add constraint profiles_role_check check (role in ('player', 'admin', 'first_architect'));
