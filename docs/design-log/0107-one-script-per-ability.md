# 0107: One script per ability

- **Date:** 2026-10-18
- **Status:** Proposed
- **Decision:** Each ability is a script extending `Ability`
  (`scripts/abilities/`): its data (id, name, action, price, text, cost)
  set in `_init`, `use_by_player()`, its own `start(...)` for bosses,
  `step()`, `active()`, `cancel()`, and how it reacts to other moves and
  jumps. `MoveSet` gives each body (player or boss) its own instances.
  Adding one: write the script, list it in `Abilities.SCRIPTS`, give its
  action a key in `Controls`.
- **Why:** abilities were spread over a data table, one shared moves
  class and a match in PlayerShape. Per-ability data in one place also
  suits sending content as data later (log 0101).
