# 0093: Clients smooth other shapes; your own stays raw

- **Date:** 2026-10-18
- **Status:** Superseded by 0095
- **Decision:** The server sends each player's and enemy's position and
  rotation as one value every frame. Clients draw other players and enemies
  60 ms behind, blended between the updates around that moment, and snap
  when a body moves 300 px+ in one update (elevators, going home). Your own
  shape uses the newest update. No client-side prediction yet. A dedicated
  server caps itself at 120 fps so it doesn't send updates as fast as the
  CPU allows.
- **Why:** snapping to each update stutters whenever packets arrive
  unevenly or the client's framerate differs from the server's. Smoothing
  your own shape would add delay to steering.
