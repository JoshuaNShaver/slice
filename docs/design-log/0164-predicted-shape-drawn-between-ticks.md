# 0164: Your predicted shape is drawn between physics ticks

- **Date:** 2026-10-20
- **Status:** Superseded by 0169
- **Decision:** Your own predicted shape, and the camera on it, are drawn
  between its last two physics ticks by how far the frame is into the
  next, plus any correction still fading. Corrections ignore errors under
  3 px, 0.05 rad and 25 px/s, and take a quarter of a bigger one per
  update (0162 took half). Refines 0162.
- **Why:** drawn straight from physics ticks (120 a second), which don't
  line up with frames, the shape and camera stuttered; at 144 fps its
  speed jumped 47 px/s a frame, against 20 before prediction, and 13 now.
  Chasing tiny timing errors dragged the shape after every key.
