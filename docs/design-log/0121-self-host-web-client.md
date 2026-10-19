# 0121: The game server hosts the web client

- **Date:** 2026-10-18
- **Status:** Accepted
- **Decision:** The web client is served from the game server's own
  domain, `https://flatland-online.duckdns.org/`, not itch.io. Each deploy
  exports it on the server (`activate-release.sh`, into the release's
  `build/web`, using a web template `setup-server.sh` installs), so client
  and server always come from the same commit and roll back together.
  Caddy sends WebSocket upgrades to the game and serves everything else
  from `/opt/slice/current/build/web`, compressed and revalidated on every
  load. The page is in Supabase's login redirect list. itch.io, if used,
  is only a page linking here. Changes the itch.io line of 0103.
- **Why:** Google login won't run inside itch.io's frame, browsers limit
  storage in frames, an installable app (0122) needs its own site, and one
  deploy updates both sides of the version check (0109).
