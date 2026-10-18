# 0021: Stats and level scaling

- **Date:** 2026-10-17
- **Status:** Accepted (numbers marked * are proposed tuning)
- **Decision:** Six stats, all 0 at level 1: **vigor** (health), **mettle**
  (energy regen), **force** (damage), **rigidity** (defense), **torque**
  (spin speed), **luck** (log 0023). Realm of the Mad God scaling: each level
  adds a random 1–2 to vigor, mettle, force and torque, and they grow about
  3x from level 1 to 20. Rigidity comes only from armor and never levels.
  - Health = 200 + 10 × vigor (200 → ~480).
  - Energy pool is always 100. Regen = 5/s* + 0.35/s* per mettle (5 → ~15/s).
  - Corner damage = (180° − corner) × 0.5* × (1 + 0.07* × force). Triangle:
    60 → ~178.
  - Torque: top spin and spin build-up × (1 + 0.07* × torque) (~3x).
  - Rigidity subtracts flat from each hit, but a hit always does at least 15%*.
- **Why:** the base regen of 1/s first suggested meant 25 s per jump at level
  1, and the level-based damage multiplier grew 7x, so the numbers were
  reshaped to hit ~3x.
