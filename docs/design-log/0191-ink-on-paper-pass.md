# 0191: An ink-on-paper pass over the world

- **Date:** 2026-10-21
- **Status:** Superseded by 0194
- **Decision:** A full-screen shader (`InkPass`) over the world and the
  main menu's picture, under the UI: lines boil (shift about a pixel, 6
  times a second, like redrawn frames), ink bleeds a little into the
  paper, the paper has fibrous grain pinned to the world, and the screen's
  edges darken. Underground the bleed fades so chalk lines stay. Off on
  Low graphics.
- **Why:** the user asked for a more hand-drawn look. Toon shaders are for
  lit 3D; in 2D the hand-drawn feel comes from boil, bleed and paper.
