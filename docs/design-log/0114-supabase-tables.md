# 0114: Saves in two Supabase tables only the server can touch

- **Date:** 2026-10-18
- **Status:** Proposed
- **Decision:** `families` (user_id, slot 0–2, data = the family save as
  JSON) and `chests` (user_id, items), keyed by `auth.users(id)` and
  deleted with the user. Row level security is on with no policies, and
  `anon`/`authenticated` have no grants, so a player's publishable key or
  login token can't read or write them; only the server's secret key can.
  The server talks to PostgREST (`SupabaseStore`): one write per slot at a
  time, newest data wins, failures retried with a growing delay, unsent
  writes overlaid on loads. A dedicated server with only one of
  `SUPABASE_URL` / `SUPABASE_SECRET_KEY` refuses to start.
- **Why:** the save stays one JSON document per slot, as on disk, so the
  format has one owner (`PlayerSave`, `Family`) and needs no migration when
  it grows.
