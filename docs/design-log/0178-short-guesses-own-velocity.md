# 0178: Short guesses use the update's own velocity

- **Date:** 2026-10-21
- **Status:** Accepted
- **Decision:** A client's guess past the newest update uses that update's
  own velocity and spin for the first 0.05 s, blending into the 0.2 s
  average (log 0169) by 0.25 s. Stalls still coast on the average.
- **Why:** the average moved a tumbling shape's center sideways while its
  spin turned it, so between ordinary updates its corners were drawn dug
  into the ground, and tumbling felt squishy. Its own velocity and spin
  turn it about the corner it's on.
