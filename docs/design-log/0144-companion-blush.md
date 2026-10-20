# 0144: The companion blushes

- **Date:** 2026-10-19
- **Status:** Superseded by 0151
- **Decision:** A `blush` animation from the user's four pictures (a
  blushing smile, startled, hearts, hiding in her sleeve) plays by itself
  every 18-35 s while she rests (`every` in anim.cfg; any animation can
  have one, and blink defaults to 2.5-5 s). Each frame's `blush` areas
  (Rect2s in its own pixels) are drawn pink by `companion_pop.gdshader`.
  Pictures exported with a background are cleaned into ink on clear by
  `tools/companion_ink.py` (removes the local background tone, keeps the
  lines); originals stay in `originals/`, which Godot ignores.
- **Why:** the user added blush pictures with a gray vignette baked in,
  which the shader would have lit up as ink.
