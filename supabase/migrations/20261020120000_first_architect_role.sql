-- The "josh" role becomes "first_architect" (design log 0152): the admin
-- whom imsdow (the second architect) talks to in the first person. Set only
-- by a database update, like admin:
--
--   update public.profiles set role = 'first_architect' where username = 'SomeName';

alter table public.profiles drop constraint profiles_role_check;
update public.profiles set role = 'first_architect' where role = 'josh';
alter table public.profiles
	add constraint profiles_role_check check (role in ('player', 'admin', 'first_architect'));
