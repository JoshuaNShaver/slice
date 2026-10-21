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
  clients; log 0106) and its child-node parts: `PlayerMotion` (rolling,
  jumps, teleports, rides), `PlayerMoves` (using abilities), `PlayerCombat`
  (hits, healing, death), `PlayerStats`, `PlayerInventory` (bag, gear,
  chests), `PlayerActions` (NPCs, shops, missions, marriage), `PlayerScreen`
  (server -> owner HUD messages), `PlayerChat` (chat lines and admin
  commands, log 0124; `Diagnostics` writes up `\diagnostics` and `\diag live`, and parses `\simulate lag`, logs 0155, 0159),
  `PlayerInput` (owner's keys);
  `PlayerSave` (progress save format and sanitizing). `Regions` (where each place is, spawn points, who a gate admits),
  terrain per region: `CenterTerrain`, `UpperEast` (Noble Quarter, Priests'
  Hill), `Underworld` (the Undercroft hub, earth band), `Cave` (training cave
  off the Undercroft), `Barracks` (drill yard, General, Quartermaster).
  `Mission` (one squad's instanced battlefield) and `Missions` (server-side
  musters, pay, discharge). `Npc` (talkers, priests, healers; built from each
  terrain's `NPCS` data), `Elevator`, `HouseDoor` (chests), `Buildings`
  (house drawing), `Enemy`, `Pickup` (per-player loot), `NetSmoother`
  (client-side smoothing of server-simulated bodies).
- `scripts/abilities/`: one script per ability (`RushAbility`,
  `NoseDiveAbility`, `SpikeUpAbility`) extending `Ability`; `Abilities`
  (the registry, shop order) and `MoveSet` (one body's abilities, for
  players and Revolt bosses). Log 0107.
- `scripts/admin/`: admin commands typed into chat after `\` (log 0125):
  `AdminConsole` (parsing, help, who's an admin, short player ids) and one
  script per noun (`PlayerCommands`, `EnemyCommands`). Roles: `profiles.role`, set only in
  the database.
- `scripts/combat.gd`: corner-strike hit detection, shared by players and
  enemies. `scripts/gear.gd`: gear slots, tiers, item strings and icons.
- `scripts/saves/`: the server's account storage (logs 0097, 0112):
  `SaveStore` (the interface), `LocalFileStore` (JSON files),
  `SupabaseStore` (Postgres over PostgREST, queued writes with retries),
  `SaveKeeper` (when to save, log 0113), `HttpJson` (awaitable JSON
  requests). Tables: `supabase/migrations/`.
- `scripts/autoload/`: `FamilyStore` (the menu's view of this machine's 3
  local slots, `user://families/`; chests in `user://chests.json`),
  `Accounts` (child of Net: login, server-held family slots, saving),
  `Controls` (input actions, default keys, rebinding saved
  to `user://controls.cfg`), `Touch` (playing by touch or keys; log 0122), `Graphics` (framerate cap, High/Low, saved to
  `user://graphics.cfg`), `Net` (offline / host / join over WebSocket, the online server's address, server-owned player list,
  version handshake; a client joins through `LagPeer`, which `\simulate lag`
  slows, log 0159),
  `HotReload` (dev only, see Running).
- `scripts/family.gd`: family data, starting-triangle choices, save format.
- `scripts/stats.gd`: stat formulas (health, energy, damage, torque, luck).
- `scripts/shape_geometry.gd`: polygon outlines. `scripts/web_app.gd`: the
  web build's update-and-reload (log 0122). `scripts/ui/`: palette, item slot,
  theme, HUD, touch controls, chat box (and its admin terminal's
  `ConsoleCompanion`, imsdow, whose lines are in `imsdow.cfg` and animations are folders of text or picture
  frames in `assets/companion/<animation>/`, colored by
  `companion_pop.gdshader`; `tools/companion_ink.py` cleans pictures into
  ink; logs 0138, 0141, 0143-0146), shape icon, stat bar, parchment background, atmosphere
  (foreground dust/light/fog), menu (Offline / Online, log 0119), online
  login, Google sign-in button.
- UI is built in code from a bare root node; scenes stay minimal.
- Fonts: `assets/fonts/` (DejaVu subsets, log 0136). The web build has no
  system fonts, so a symbol must be in one of them to show there.

## Running

Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot` (4.5.1).
- Check scripts: `Godot --headless --path . --quit-after 60`
- Dedicated server: `Godot --headless --path . -- --server --port=24680`
- `make web-local`: the local stack, in the deploy workflow's order:
  Supabase settings (starts Docker/Supabase; restarts it when
  `supabase/config.toml` or `.env`'s Google settings changed), migrations
  (`supabase migration up --local`), web export, then server + page on
  127.0.0.1:8000, checked, with a banner of URLs (Studio too). Ctrl-C stops
  server and page. `SAVES=local` skips Supabase and uses the LAN IP. Also
  `make server`, `migrate`, `stop`, `supabase-stop`, `supabase-reset`, `check`.
- **Hot reload:** a server or game run from source reloads any `.gd` file
  you save, keeping node state. `_ready` doesn't rerun; give a node a
  `_hot_reload()` method to rebuild (Hud rebuilds itself, CenterTerrain
  its collision). Scripts with errors are skipped. `.tscn` edits and
  `@rpc` changes need a restart. A new `class_name` needs an import scan
  first (open the editor, or `Godot --headless --path . --import`). Disable with `-- --no-hot-reload`.
- Exporting builds (macOS, Web) and LAN play: see `docs/EXPORT-AND-LAN.md`.
  Web export: `Godot --headless --path . --export-release "Web" build/web/index.html`.
  Deploys export it on the server, and Caddy serves it (log 0121).
  Guard web-only limits with `OS.has_feature("web")` (no hosting, no threads,
  Compatibility renderer).
- The online server (Hetzner VPS, provisioned and deployed by manual GitHub
  Actions, keys as GitHub secrets): see `deploy/README.md`.
- Player smoke test: `Godot --headless --path . -s tools/tests/test_player.gd`
  (prints RESULT lines to compare before and after a refactor).
- Save test (offline, temp folder): `-s tools/tests/test_saves.gd`. Online
  test against a running server: `-s tools/tests/test_online.gd -- --port=N`
  (see the file; start that server with `--dev-admins`, since the test
  levels up with an admin command). Chat and admin commands:
  `-s tools/tests/test_chat.gd`; the admin terminal and imsdow:
  `-s tools/tests/test_imsdow.gd`. A dev server can keep saves elsewhere with
  `-- --server --save-dir=user://some-folder/`. `SAVES=local|supabase`
  picks its store (log 0117); settings are in `.env.example`, steps in README.md "Saves and logins". Quick tests use a
  mock Supabase, `python3 tools/tests/supabase_mock.py` (see its header;
  `test_supabase_store.gd` needs it). Real local Supabase (Docker Desktop
  running, `~/.docker/bin` on PATH): `supabase start` applies the
  migrations; `supabase status` gives URL and keys. Both use port 54321, so
  run one at a time. `test_online.gd --token=` takes a real token (a
  password user made with the admin API).
- Test scripts run with `-s`; autoloads are ready only after the first
  `await process_frame`. Don't leave test families in the real save folder.

## Code conventions

- Multiplayer is supported from the start: server-authoritative. Gameplay
  state changes happen on the server; clients send input. Single player runs
  as a local server. Don't optimize networking yet.
- Bump `application/config/version` in `project.godot` with any change an
  older client or server couldn't play with (RPCs, synced properties,
  content sent over the network). Clients and servers must match exactly
  (design log 0109). Never change the RPCs in `scripts/autoload/handshake.gd`.
- `docs/` has a `.gdignore` so Godot doesn't import it.
