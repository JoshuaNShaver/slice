# 0106: PlayerShape is split into child-node components

- **Date:** 2026-10-18
- **Status:** Proposed
- **Decision:** `PlayerShape` is the body (identity, outline, drawing,
  step order). Each job is a child node made in `create()`, same names and
  order on server and clients so RPCs and synced paths (`Stats:hp`,
  `Inventory:bag`) line up: `Motion`, `Moves`, `Combat`, `Stats`,
  `Inventory`, `Actions`, `Screen`, `Input`. Each owns its state and its
  RPCs. `PlayerSave` is the one place that knows the save format (progress
  from `Stats` + `Inventory`, chests), ready to sit behind log 0097's
  storage interface.
- **Why:** one 1,250-line file mixed eight jobs. Nodes, not RefCounted
  helpers, because RPCs and the synchronizer address nodes by path.
