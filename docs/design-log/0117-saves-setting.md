# 0117: SAVES chooses a dedicated server's store

- **Date:** 2026-10-18
- **Status:** Accepted
- **Decision:** A dedicated server reads `SAVES`: `local` (its own folder,
  device-id logins; Supabase settings ignored) or `supabase` (all of
  `SUPABASE_URL`, `SUPABASE_SECRET_KEY`, `SUPABASE_PUBLISHABLE_KEY`
  required, else it won't start). Unset keeps log 0112's rule (Supabase if
  its settings are there, else local). The online server is installed with
  `SAVES=supabase`. Offline and hosting from the menu always use local files.
- **Why:** one switch in `.env` to flip between the two, and a server
  missing a key fails loudly instead of quietly saving to its own disk.
