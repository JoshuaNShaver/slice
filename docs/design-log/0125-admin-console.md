# 0125: Admins and the admin console

- **Date:** 2026-10-18
- **Status:** Accepted
- **Decision:** Accounts have a role, `player` or `admin`
  (`profiles.role`), set only by a database update. Admins type commands
  into chat after `\`, like a command line: `\<noun> <verb> [words]
  [--flags]`. `\help` lists nouns, `\player help` a noun's verbs, `--help`
  a verb's usage. First noun, `player`: `list` (online: short id, name,
  level), `get [who]`, `set <level|xp|pay|hp> <value> [--id who]`,
  `levelup [count] [--id who]`. `who` is a short id (small numbers given
  out in join order while the server runs), a name, or `me` (the default).
  Setting a level rolls each level's stat gains, as leveling does (going
  down re-rolls from level 1). Only the asker sees the answer; the server
  logs every command. Offline and a host's own player are admins (it's
  their game). A dedicated server started with `--dev-admins` makes
  everyone an admin, for tests and dev servers. The debug `L` level-up
  key is gone.
- **Why:** the online server runs from source, so the debug level-up was
  open to anyone running a debug client; tools for testing and running the
  live game need to be server-checked and admin-only.
