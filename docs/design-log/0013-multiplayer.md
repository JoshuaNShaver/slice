# 0013: Multiplayer supported from the start

- **Date:** 2026-10-17
- **Status:** Accepted (architecture: proposed)
- **Decision:** Online multiplayer like Realm of the Mad God / Borne Again.
  Support it from the start; don't optimize it yet.
- **Proposed approach:** server-authoritative with Godot high-level
  multiplayer (ENet, MultiplayerSpawner, MultiplayerSynchronizer). Single
  player runs as a local server with one peer.
