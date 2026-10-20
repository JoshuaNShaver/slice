# 0143: Picture frames for the companion, colored to pop

- **Date:** 2026-10-19
- **Status:** Accepted
- **Decision:** Companion frames may be pictures (`.png`, black ink on
  clear) as well as text. Her wave is the user's four pictures
  (`assets/companion/wave/frame_1..4.png`): looking back, raising a hand,
  waving with closed eyes, waving with an open smile; she rests on frame 1.
  `anim.cfg` adds `sequence` (frame numbers to play) and `offsets` (per
  picture, image px) to line the drawings up. `companion_pop.gdshader`
  colors the ink by density: hatched hair and clothes a hot pink to violet
  gradient with a cyan shimmer sweeping over, face and hand lines near
  white, a soft glow behind. Pictures need mipmaps on import (the shader
  blurs with them). There's no idle or blink yet; add an `idle/` or
  `blink/` folder to get them.
- **Why:** the user drew a nicer waving sequence as pictures and wanted
  her to stand out in color.
