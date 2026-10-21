# 0160: Diagnostics show the longest frame

- **Date:** 2026-10-20
- **Status:** Accepted
- **Decision:** `\diagnostics` and `\diag live` show the longest frame of
  the last 10 s, on your machine and on the server ("worst N ms" in the
  live panel; frames up to 25 ms don't count). A big update gap with no
  long frames on either side points at the connection.
- **Why:** on prod, gaps between updates sometimes passed 200 ms; this tells
  a stalled connection from a stalled game.
