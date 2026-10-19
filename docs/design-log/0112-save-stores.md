# 0112: Save stores, and who uses which

- **Date:** 2026-10-18
- **Status:** Proposed
- **Decision:** The server loads and saves each account (3 family slots,
  house chests) through `SaveStore` (log 0097). `LocalFileStore` keeps JSON
  files: offline and a LAN host's own player are the "local" account in
  today's `user://families/` and `user://chests.json`, so offline looks and
  works as before. LAN joiners keep working: a host (or a dedicated server
  without Supabase settings, for dev) logs them in by a random device id
  and keeps their saves in its own `accounts/guest-<id>/` folder. A
  dedicated server with `SUPABASE_URL` and `SUPABASE_SECRET_KEY` uses
  `SupabaseStore` and needs a real login (log 0115). Clients never send a
  save; whatever they send on registering is ignored, and the server still
  checks its own save (`PlayerSave.sanitize`). A store that can't load an
  account turns the player away rather than letting them play over it.
- **Why:** one code path for every mode. LAN saves now live on the host,
  not the joiner: the price of the server owning saves. Changes log 0064's
  "chests saved on the player's machine".
