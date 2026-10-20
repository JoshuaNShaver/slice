# 0153: \help for players: \hello and \bye

- **Date:** 2026-10-20
- **Status:** Accepted
- **Decision:** For a player who isn't an admin or the first architect,
  `\help` (or a lone `\`) answers with just `\hello` and `\bye`, not
  "Only admins..."; other commands still say only admins can use them,
  and point to `\help`. New `\hello`: like `\bye`, it's handled in the
  terminal and never sent: imsdow waves and says a `hello` line (asleep,
  it wakes her). Works for admins too.
- **Why:** the user asked for it.
