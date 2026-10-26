# 0220: Ribbons hang at rest and move each on its own

- **Date:** 2026-10-22
- **Status:** Accepted (feel numbers Proposed)
- **Decision:** At rest, regimental ribbons hang straight down and stir
  gently in the wind. Moving, each ribbon trails straight back behind its
  own corner, a moment late, rather than all of them swinging round
  together. Supersedes log 0219's ribbon part (the wave-jump removal
  stands).
  - *Proposed:* each ribbon is a short simulated chain pinned at its
    corner (gravity, its own breeze, air drag, a little stiffness), drawn
    in world space; numbers in `Gear.RIBBON_*`.
- **Why:** the user found the shared, turning ribbons obnoxious: real
  ribbons go straight back, and not all at the same time.
