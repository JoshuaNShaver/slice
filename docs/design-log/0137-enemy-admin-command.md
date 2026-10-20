# 0137: `\enemy` admin commands

- **Date:** 2026-10-19
- **Status:** Accepted
- **Decision:** `\enemy list [--away] [--type name]` (short: `\enemies`)
  and `\enemy get <name>` show every enemy's name, type, hp, position and
  distance from home. "AWAY" marks one outside its area and over 300 px
  from home. Admin console aliases (`AdminConsole.ALIASES`) map a short
  word to longer ones.
- **Why:** the drill yard's sparring partners are missing on prod but not on
  a fresh local server; this shows whether they're stuck or gone before
  adding an automatic reset.
