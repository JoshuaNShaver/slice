# 0214: Admin commands for items

- **Date:** 2026-10-22
- **Status:** Accepted
- **Decision:** `items list [search]` lists every kind of item (consumables, notes, each valid gear tier and slot) by id and name; the search matches either, ignoring case, as a substring, or as a pattern when it has `*` (`*steel*`, `points_*`). `items create <item> [count] [--id who]` (count 1-99) puts them in the player's bag, as many as fit; gear may be upgraded (`points_9+3`), and notes fill stacks.
- **Why:** testing gear, upgrades and trades without grinding for items.
