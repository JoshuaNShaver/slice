# 0162: Abilities predicted too; gentler corrections

- **Date:** 2026-10-20
- **Status:** Accepted
- **Decision:** Changes 0161. Your own shape also uses its abilities on your
  machine (Spike Up throws enemies only on the server), so starting one no
  longer hands the shape to the server; it follows only for rides,
  teleports, being thrown and death. It collides with enemies too, not
  just terrain. A correction moves the body only as far as it fits before
  touching something, turns it only in the air, and takes the server's
  velocity outright only when 600 px/s or 20 rad/s off.
- **Why:** at 150 ms of lag the drill yard felt almost unplayable: each
  ability slid your shape back a round trip and yanked it forward after,
  passing through enemies became corrections, and fixes that pushed the
  shape into the ground made it pop.
