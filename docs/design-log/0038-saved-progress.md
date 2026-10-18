# 0038: Saved progress

- **Date:** 2026-10-17
- **Status:** Accepted
- **Decision:** The family save keeps the current heir's level, XP, stats,
  bag and worn gear, alongside the lineage (generation, shape, apex, luck).
  The player's own machine saves every 3 s, on leaving and on quitting.
  On joining, the server checks the save and caps anything out of range
  (level 20, stats 2 per level, valid items only) before restoring it.
  A new heir starts fresh, and death still ends the family.
- **Why:** saves are still local (DESIGN §5b), so the server can't fully
  trust them; a server-held save is the later fix.
