# 0192: A word before each cutscene

- **Date:** 2026-10-21
- **Status:** Accepted
- **Decision:** Talking to someone rarely (if ever) cuts straight to a
  cutscene. In a quest, every cutscene is led in by the person saying
  something in the world first (a cutscene action's `lead`), and it starts
  once the line has had time to be read. A cutscene also fades in over the
  world instead of appearing at once.
- **Why:** going straight into a cutscene felt abrupt.
