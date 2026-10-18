# CLAUDE.md

Godot 4.5 game: a multiplayer Flatland roguelite. GDScript.

## Design docs: read first, record always

- `docs/DESIGN.md` is the **current** design. Read it before any design or
  gameplay work.
- `docs/design-log/NNNN-slug.md` is the **decision history**, one decision
  per file, numbered in order. Skim the titles (`ls docs/design-log`) and
  read the logs for the area you're touching.

When a design decision is made (by the user, or proposed by you and accepted):

1. Add a new log with the next number: `docs/design-log/00NN-short-slug.md`.
2. Use this format, and keep it to a few lines:
   ```
   # 00NN: Title

   - **Date:** YYYY-MM-DD
   - **Status:** Accepted | Proposed | Superseded by 00NN
   - **Decision:** what was decided.
   - **Why:** one or two lines (optional).
   ```
3. Update `docs/DESIGN.md` to match.
4. Never rewrite an old log's decision. To change one, write a new log and
   set the old one's status to `Superseded by 00NN`.
5. Resolved an open question? Remove it from DESIGN.md §9 and log the answer.

Mark your own suggestions `Proposed` until the user agrees.

## Layout

- `scenes/`: `main_menu.tscn` (main scene), `world.tscn` (the Center hub).
- `scripts/world/`: `PlayerShape` (server-simulated rolling polygon, synced to
  clients) and `CenterTerrain` (hub ground, ledges, signs).
- `scripts/autoload/`: `FamilyStore` (3 local save slots in
  `user://families/`), `Net` (offline / host / join, server-owned player list),
  `HotReload` (dev only, see Running).
- `scripts/family.gd`: family data, starting-triangle roll, save format.
- `scripts/stats.gd`: stat formulas (health, energy, damage, torque, luck).
- `scripts/shape_geometry.gd`: polygon outlines. `scripts/ui/`: palette,
  theme, shape icon, stat bar, parchment background, menu.
- UI is built in code from a bare root node; scenes stay minimal.

## Running

Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot` (4.5.1).
- Check scripts: `Godot --headless --path . --quit-after 60`
- Dedicated server: `Godot --headless --path . -- --server --port=24680`
- **Hot reload:** a server or game run from source reloads any `.gd` file
  you save, keeping node state. `_ready` doesn't rerun; give a node a
  `_hot_reload()` method to rebuild (World rebuilds the HUD, CenterTerrain
  its collision). Scripts with errors are skipped. `.tscn` edits and
  `@rpc` changes need a restart. Disable with `-- --no-hot-reload`.
- Test scripts run with `-s`; autoloads are ready only after the first
  `await process_frame`. Don't leave test families in the real save folder.

## Code conventions

- Multiplayer is supported from the start: server-authoritative. Gameplay
  state changes happen on the server; clients send input. Single player runs
  as a local server. Don't optimize networking yet.
- `docs/` has a `.gdignore` so Godot doesn't import it.
