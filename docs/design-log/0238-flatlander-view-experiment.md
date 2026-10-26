# 0238: A Flatlander's view, as an experiment

- **Date:** 2026-10-25
- **Status:** Accepted (an experiment, client only; the side view stays the default; how an eye looks, its width and turning superseded by 0239)
- **Decision:** `\view` (anyone, never sent) picks how you see the world:
  `2d` (the side view), `eyes`, `eye`, `2d eyes`, `2d eye`. An eye is a
  vertical bar of colour, up the bar being up the world: rays from your
  shape meet the first solid thing, far things fade into fog (dark above
  ground, pale below), and depth jumps are inked as edges. Two eyes look
  west and east, each from straight up to straight down. One eye turns
  toward the mouse and sees 180° around where it looks, so facing west it
  sees the world upside down, as a Flatlander turning in the plane must.
  With `2d` the bars are drawn over the side view, for debugging. The HUD
  is unchanged.
- **Why:** to try seeing the plane as its people would. Vertical, not the
  book's horizontal line, because our world is seen side-on, not from above.
