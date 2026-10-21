# 0196: Plural admin commands, one `\`, and quest commands

- **Date:** 2026-10-21
- **Status:** Accepted
- **Decision:** Admin nouns are plural, each the root of the commands on
  that kind of thing: `players`, `enemies`, `quests` (the singular
  `player`/`enemy` and the aliases are gone). A noun alone runs its list
  (`players`, `enemies --away`). A `\` opens the terminal; in it, lines need
  no `\` (every line is a command, so there's no chatting from it).
  `players quests` is a player's place in each quest:
  `[list]`, `get <quest>`, `start <quest>` (runs the first step's actions,
  as play would), `set <quest> <step|done>` (begun or not; counts at 0;
  only a bout the step needs comes back, as when a save loads on it),
  `delete <quest>` (as if never begun); all take `--id who`. Steps count
  from 1. `quests [list]` and `quests get <quest>` show the quests
  themselves, read-only (they're code).
- **Why:** the user asked for it: one consistent tree, and a way to test
  and fix quest progress.
