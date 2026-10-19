# 0101: The server owns content, the client owns presentation

- **Date:** 2026-10-18
- **Status:** Accepted
- **Decision:** Content (items, abilities, prices, shops, NPCs and their
  text) is data the server owns and sends to clients on joining. The
  client keeps how things look: theme, widgets, HUD layout, rendering,
  smoothing. No server-driven UI layouts.
- **Why:** content changes then need no client update. Real-time feedback
  has to stay in the client, and the web build already ships the newest
  client on every page load.
