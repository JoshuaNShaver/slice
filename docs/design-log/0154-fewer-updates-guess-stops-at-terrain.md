# 0154: 30 updates a second; late guesses stop at terrain

- **Date:** 2026-10-20
- **Status:** Superseded by 0158
- **Decision:** The server sends each player's and enemy's state 30 times a
  second, not every frame (120). Clients draw other bodies 100 ms behind
  (was 60), and when updates run late a body keeps moving at its last
  velocity for up to 250 ms (was 100). That guess stops at whatever the body
  would hit and slides along it. Refines 0095.
- **Why:** on the hosted server, shapes sank into the floor on landing when
  an update was late (the guess carried the fall on), and 120 small TCP
  packets a second per body stalled and bunched up, delaying how fast
  your inputs showed on screen.
