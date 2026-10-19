# 0105: Supabase config lives in the repo; deploys apply it

- **Date:** 2026-10-18
- **Status:** Accepted
- **Decision:** Database migrations (`supabase/migrations/`) and auth
  settings (`supabase/config.toml`) are kept in the repo and applied by the
  Supabase CLI in the deploy workflow, before the game server deploys.
  Migrations must work with the server version still running. All keys are
  GitHub secrets; the game server gets the URL and secret key through
  Provision, checked first. Clients get only the publishable key. Google is
  the only login for now (Discord skipped).
- **Why:** same flow as the server: nothing set by hand, every change reviewed.
