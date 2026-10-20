# 0136: A bundled symbols font

- **Date:** 2026-10-19
- **Status:** Accepted
- **Decision:** `assets/fonts/symbols.ttf` (a DejaVu Sans Bold subset: arrows,
  ✕, a few marks) is added as a fallback to Godot's default font at startup
  (`Graphics`). New symbols in UI text must be in it; re-subset DejaVu to add more.
- **Why:** the web build has no system fonts to fall back on, so ← → ✕ drew as boxes.
