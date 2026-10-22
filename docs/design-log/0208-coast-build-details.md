# 0208: Coast build details

- **Date:** 2026-10-21
- **Status:** Proposed (built)
- **Decision:** Details chosen while building the coast (logs 0200-0202):
  - Layout, east to west: the Harbour Watch's gate at x -5700, a ~15°
    slope down to the dock, a pier, ~4,000 px of open sea, the Logging Isle
    (its own pier and boatwright, 6 trees), more sea to the world's edge.
  - Waves are calm at every shore and rough out at sea; the server's clock
    drives them so every peer sees the same sea.
  - A Boatwright (one at the dock, a mate on the isle) launches your own
    boat; one per player, gone when you leave or take another.
  - Sailing: rolling into the sail leans the boat and drives it (~300 px/s
    at best). The lean keeps building while you hold it: about 4 s of
    holding rolls it over, so you sail in bursts. The use key turns the
    boat about, which you need to step off onto a pier (the sail is in the
    way otherwise).
  - Drowning loses everything in the bag, potions too; worn gear is kept.
  - A log drops at the tree for the chosen hitter, as loot (pick it up).
    Felled trees regrow in 3 minutes.
