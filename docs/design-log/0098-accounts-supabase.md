# 0098: Accounts with social login through Supabase

- **Date:** 2026-10-18
- **Status:** Accepted
- **Decision:** Online play needs an account. Login is social (Google,
  Discord, etc.) through Supabase Auth. The client sends its Supabase token
  on joining; the game server checks it and loads that account's data.
  Offline play needs no login.
- **Why:** the server needs to know who you are to own your save (0097).
  Supabase also gives Postgres for storage, so one service covers both.
