# 0161: Your own shape is predicted

- **Date:** 2026-10-20
- **Status:** Superseded by 0162
- **Decision:** Online, your own shape rolls and jumps on your machine the
  moment you press a key (PlayerMotion.integrate, as on the server), and
  only collides with terrain there. Inputs carry your physics clock, so each
  server update says which moment of yours it matches; the difference from
  where you were then is taken half at once by the body, while the drawing
  catches up over about 0.1 s. 160 px+ off jumps to the server. While the
  server alone moves you (a ride, a teleport, thrown, an ability under way,
  dead) the shape follows the server's updates, as before. The server
  still decides everything, combat included. Changes 0093/0095's "no
  client-side prediction yet".
- **Why:** at an 80 ms ping, every key showed up a round trip late.
  Abilities and being hit still do.
