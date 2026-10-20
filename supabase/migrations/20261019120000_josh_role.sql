-- The "josh" role (design log 0147): an admin whom imsdow, the admin
-- terminal's companion, talks to in the first person. Other admins hear her
-- talk about Josh. Set only by a database update, like admin:
--
--   update public.profiles set role = 'josh' where username = 'SomeName';

alter table public.profiles drop constraint profiles_role_check;
alter table public.profiles
	add constraint profiles_role_check check (role in ('player', 'admin', 'josh'));
