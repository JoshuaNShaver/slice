# 0141: The companion's animations are text files

- **Date:** 2026-10-19
- **Status:** Accepted
- **Decision:** The terminal companion is drawn from plain text frames,
  edited by hand: `assets/companion/<animation>/01.txt, 02.txt...`, played
  in name order, with an optional `anim.cfg` (`[anim] frame_time`,
  `repeat`). `idle` shows between animations, `wave` plays on hello,
  `blink` every few seconds. Frames are padded to one size, and she's
  sized to fit the space. Her art is the user's dotted portrait; the
  generator (`tools/companion_art.py`, 0139) is gone. Exports include
  `assets/companion/*` (plain text isn't exported by default).
- **Why:** generating frames by string manipulation was hard to adjust;
  a folder of frames per animation can be edited directly.
