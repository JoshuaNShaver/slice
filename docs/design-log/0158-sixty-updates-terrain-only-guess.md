# 0158: 60 updates a second; late guesses stop at terrain only

- **Date:** 2026-10-20
- **Status:** Proposed
- **Decision:** The server sends each body's state 60 times a second (log
  0154 had 30). Other bodies are drawn 60 ms behind again (0154 had 100).
  A late guess still runs up to 250 ms and stops at terrain, but only at
  terrain: not at enemies or players, and the push out of a slight overlap
  doesn't count as movement. Supersedes 0154.
- **Why:** after 0154 play felt laggy and glitchy. Enemies are drawn behind
  where they are, so stopping your own shape at them blocked it in the
  wrong place, and 100 ms put them visibly out of step with you.
