# 0126: Fill the window, parchment splash

- **Date:** 2026-10-19
- **Status:** Accepted
- **Decision:** The game fills any window shape (stretch aspect `expand`):
  1280x720 is the minimum view, and wider or taller windows see more world
  instead of black bars. The boot and web loading screens show the game
  icon on parchment, not Godot's logo.
- **Why:** black bars looked broken in browsers, whose windows are rarely 16:9.
