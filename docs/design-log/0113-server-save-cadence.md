# 0113: The server saves on what matters, and every 45 s

- **Date:** 2026-10-18
- **Status:** Proposed
- **Decision:** The server checks each player every 3 s and writes only
  what changed: at once for a meaningful change (level, bag, gear,
  abilities, chests), but at most every 10 s per player; XP and pay alone
  wait up to 45 s. Leaving, dying, marrying and closing a local server save
  at once. Supabase writes ask for no reply (`Prefer: return=minimal`).
  A dedicated server stopped hard may lose up to 45 s of XP. Changes log
  0038's "the player's own machine saves every 3 s".
- **Why:** Supabase's free tier allows ~5 GB egress a month; saving every
  3 s for every player would waste it for nothing a player would miss.
