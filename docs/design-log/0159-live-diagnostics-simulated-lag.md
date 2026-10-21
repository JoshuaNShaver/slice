# 0159: Live diagnostics, and simulated lag

- **Date:** 2026-10-20
- **Status:** Accepted
- **Decision:** `\diag live` (or `\diagnostics live`) turns on a small
  panel at the top right, under your pay, that stays up while you play
  until you type it again: fps and frame time, ping (the last 5, one a
  second), how your shape's updates arrive, and the server's fps, physics
  time and players. It stays on across families until the game closes.
  `\simulate lag <ms> [jitter ms]` adds that much round-trip lag to your
  own connection (half each way, jitter at most half the lag, up to
  5000 ms); `\simulate lag off` stops it. Online only, anyone may use it,
  and it's never sent: every joining client's connection goes through
  `LagPeer`, which passes packets straight on when there's no lag. Both
  show in `\diagnostics` and both `\help`s.
- **Why:** the user asked for it, to watch lag while playing and to test
  it locally.
