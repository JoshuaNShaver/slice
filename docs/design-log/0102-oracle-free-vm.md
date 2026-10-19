# 0102: Game server on an Oracle Cloud Always Free VM

- **Date:** 2026-10-18
- **Status:** Superseded by 0103
- **Decision:** The online game server runs headless on an Oracle Cloud
  Always Free ARM VM (Linux ARM64 server build), behind Caddy for `wss://`.
  The web client is hosted on itch.io (restricted) and logs in via Supabase.
- **Why:** free, always on, and big enough for this stage.
