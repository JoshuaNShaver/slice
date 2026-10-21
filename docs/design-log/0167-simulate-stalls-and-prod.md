# 0167: \simulate stalls and \simulate prod

- **Date:** 2026-10-20
- **Status:** Accepted
- **Decision:** `\simulate stalls <ms> [every <s>]` makes your connection
  stall now and then (every half to one and a half times `every`, default
  5 s): nothing comes in from the server for that long, then everything
  held up arrives at once, as TCP does behind a lost packet. Incoming only.
  `\simulate prod` is the live server's profile: +35 ms (±1) with 160 ms
  stalls about every 5 s. `\simulate off` stops lag and stalls; `lag off`
  and `stalls off` stop one. Tab completes them.
- **Why:** prod has a steady ~41 ms ping but update gaps of ~160 ms, which
  `\simulate lag` alone couldn't reproduce locally.
