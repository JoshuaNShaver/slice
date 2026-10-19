# 0103: Game server on a Hetzner VPS, deployed by a manual GitHub Action

- **Date:** 2026-10-18
- **Status:** Accepted
- **Decision:** The online game server runs on a small Hetzner VPS
  (Ubuntu 24.04), from source with a plain Godot 4.5.1 binary. A manually
  run GitHub Action uploads the committed project, imports it, restarts the
  server and rolls back if it doesn't come up. A timer stops the server at
  80% of the traffic allowance. Web client on itch.io (restricted); Caddy
  for `wss://` arrives with WebSocket support. See `deploy/README.md`.
- **Why:** Oracle signup failed. A few euros a month, a predictable bill,
  and no export templates in CI.
