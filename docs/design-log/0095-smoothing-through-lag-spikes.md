# 0095: Smoothing rides through lag spikes, your own shape too

- **Date:** 2026-10-18
- **Status:** Accepted
- **Decision:** The server sends each player's and enemy's position,
  rotation, velocity and spin, stamped with its own clock, every frame.
  Clients draw other players and enemies 60 ms behind, blended between
  updates. Your own shape shows the newest update. When updates run late,
  a body keeps moving at its last velocity for up to 100 ms, and when news
  arrives the difference fades out (about 80 ms) instead of snapping. Moves
  of 300 px+ in one update still snap (elevators, going home). No
  client-side prediction yet. A dedicated server caps itself at 120 fps.
- **Why:** with 0093 your own shape froze, then jumped, on every 50 ms
  spike. Server timestamps keep updates that land in a bunch from
  bunching up on screen.
