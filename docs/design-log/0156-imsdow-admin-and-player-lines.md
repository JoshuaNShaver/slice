# 0156: imsdow's lines for admins and for players

- **Date:** 2026-10-20
- **Status:** Accepted
- **Decision:** imsdow no longer talks to the first architect in the first
  person. Every admin (`admin` or `first_architect`) gets `imsdow.cfg`'s
  lines, which are what `imsdow_about_first_architect.cfg` had (that file
  is gone): kind words to the admin, and facts about the first architect
  (as 0150). Players who aren't admins get `imsdow_non_admin.cfg`: a
  player's hellos, kind words, puns and game facts without spoilers, and
  `not_admin` lines when they try an admin command. Settings stay in
  `imsdow.cfg` for everyone. The `first_architect` role stays, as an admin.
- **Why:** the user asked for it.
