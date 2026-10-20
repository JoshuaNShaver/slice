# 0155: \diagnostics for everyone

- **Date:** 2026-10-20
- **Status:** Accepted
- **Decision:** Anyone can type `\diagnostics` (or `\diag`). It's never
  sent as a chat line: your game pings the server 5 times, 0.2 s apart,
  and the server's last answer brings its own numbers. Only you see the
  answer: version, platform and renderer; your fps, frame time, cap,
  quality and window; ping (average, low to high, any that didn't come
  back); how your shape's updates arrived over the last 10 s (per second,
  longest gap, how late compared with the quickest packets); the server's
  fps, physics time per step against its budget, players, enemies,
  memory and uptime. Offline and hosting say there's no network. Both
  `\help`s list it. The server answers at most one ping per 50 ms.
- **Why:** the user asked for it, to look into lag on the hosted server
  (log 0154).
