# 0100: Order of work before public hosting

- **Date:** 2026-10-18
- **Status:** Accepted
- **Decision:** 1) Split `PlayerShape` into components (movement, combat,
  inventory, progress). 2) Version check on join. 3) Accounts: login,
  server-owned saves, storage interface (0097, 0098). 4) WebSocket and web
  build (0099). Other refactors (e.g. one script per ability) happen as we go.
- **Why:** accounts are the real blocker for strangers; the split comes
  first because saving reworks inventory and progress code anyway.
