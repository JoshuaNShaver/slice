# 0173: Your shape plays on through gaps

- **Date:** 2026-10-20
- **Status:** Accepted
- **Decision:** Online, when the server's updates stop for 0.12 s+ (a
  Wi-Fi stall), your own shape carries on with its own physics and your
  keys (rolling, jumping, abilities; Spike Up throws enemies only on the
  server), starting from where it's drawn at its recent velocity. Once an
  update is under 0.05 s old again it hands back, fading from where it got
  to into the server's state (a teleport meanwhile jumps). The server is
  unchanged. Not during an elevator ride. Changes 0169 for your own shape;
  everything else still coasts.
- **Why:** a stall froze your controls, then raced your shape through the
  stall's motion to catch up, though the server, which had your held key,
  put you where you'd have been. In tests with 1.3 s stalls, your shape
  hands back 0-60 px off (typically 5-30) instead of racing through the
  whole stall. Keys pressed during a stall still reach the server late.
