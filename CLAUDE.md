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

## Code conventions

- Multiplayer is supported from the start: server-authoritative. Gameplay
  state changes happen on the server; clients send input. Single player runs
  as a local server. Don't optimize networking yet.
- `docs/` has a `.gdignore` so Godot doesn't import it.
