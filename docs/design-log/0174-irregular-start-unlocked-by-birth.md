# 0174: Irregular start is unlocked by being born irregular

- **Date:** 2026-10-20
- **Status:** Accepted (amended by 0175)
- **Decision:** A new family can start irregular only once the player has
  had an heir born irregular (the 1-in-10 roll). Until then the menu shows
  the irregular choice locked, and the server refuses it. The unlock
  belongs to the account and outlives families, like the chests (log
  0042): online in a Supabase `unlocks` table, otherwise an
  `unlocks.json` beside the chests. An account that already has an
  irregular family counts as unlocked. Changes log 0065.
- **Why:** the irregular start should be discovered (the Board, the chute,
  the Gleaner; logs 0168, 0171) before it can be chosen.
