# 0151: Blushing is rarer, and usually quiet

- **Date:** 2026-10-20
- **Status:** Accepted
- **Decision:** As 0144, but she blushes by herself every 90-175 s (was
  18-35). Nine times in ten the blush stops at the hearts (frames 1, 2,
  3) and she says nothing; one in ten goes on to frame 4, hiding in her
  sleeve, and says a `blushing` line. Any animation can do this:
  `sometimes`, `sometimes_chance` and `sometimes_says` in its anim.cfg.
  A blush from a click says a normal line unless it's the full one; a
  blush on waking keeps her waking line.
- **Why:** the user found blushing about 5x too frequent.
