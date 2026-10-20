-- The "first_architect" role (design logs 0147, 0152): an admin like any
-- other (log 0156). Set only by a database update, like admin:
--
--   update public.profiles set role = 'first_architect' where username = 'SomeName';

alter table public.profiles drop constraint profiles_role_check;
alter table public.profiles
	add constraint profiles_role_check check (role in ('player', 'admin', 'first_architect'));
