# 0169: No prediction; shapes coast through stalls

- **Date:** 2026-10-20
- **Status:** Accepted
- **Decision:** Client-side prediction (0161, 0162, 0164) and `\predict`
  (0165) are removed: your own shape follows the server's updates, like
  every other. When updates stop, every shape coasts on for up to 1.5 s
  (was 250 ms): at its velocity and spin over the last 0.2 s of updates,
  dying away with a 1 s time constant, and falling under gravity, moving
  first along its way, then down, each stopped by terrain and sliding
  along it. A body moved by script (zero velocity, an elevator ride) waits.
  When updates return, a big difference fades out over up to 0.25 s. The
  clock estimate drifts by time between updates (at most 50 ms each), not
  by update, so a stall's burst of late updates can't throw it off.
- **Why:** prediction felt worse on prod and at 150 ms of simulated lag
  (tumbling shapes diverge, and the corrections yanked), and a 1.3 s Wi-Fi
  stall froze the whole game. In tests with 1.3 s stalls the game no
  longer freezes (no more still frames than without stalls), and catching
  up moves a shape at most ~7 px in a frame (was ~37).
