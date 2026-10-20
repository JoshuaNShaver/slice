# 0145: The companion falls asleep

- **Date:** 2026-10-19
- **Status:** Accepted
- **Decision:** A `sleeping` animation from the user's four pictures (Zzz,
  blush, a thought bubble) plays once nothing's been typed in the terminal
  for 45 s and loops until something is (anim.cfg `after_quiet`, `loop`;
  any animation can use them). Typing wakes her: she says a waking line
  ("w-wasn't sleeping!") and plays `blush`. The pictures had a light
  background with a baked-in transparency checkerboard and no alpha, so
  `tools/companion_ink.py` gained `--paper L`, which turns everything
  lighter than L into blank paper before cleaning (0.9 here).
- **Why:** the user added sleeping pictures; dozing off when left alone
  suits a companion who waits in the terminal.
