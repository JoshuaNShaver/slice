# 0165: Prediction off by default; \predict on|off

- **Date:** 2026-10-20
- **Status:** Superseded by 0169
- **Decision:** Your own shape follows the server's updates again by
  default, as before 0161. `\predict on` (or `off`, or alone to flip it)
  turns prediction (0161, 0162, 0164) on for this game, to test; anyone may
  use it, and it's never sent. `\diagnostics` says whether it's on.
- **Why:** with prediction on, the user found the game unplayable at
  150 ms of simulated lag: the shape got yanked backwards while holding a
  direction. Until that's understood, the earlier feel is the default.
