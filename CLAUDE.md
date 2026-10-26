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
  chests), `PlayerActions` (NPCs, shops, missions, marriage, drowning,
  selling logs, market trades), `PlayerScreen`
  (server -> owner HUD messages), `PlayerChat` (chat lines and admin
  commands, log 0124; `Diagnostics` writes up `\diagnostics` and `\diag live`, and parses `\simulate lag`, logs 0155, 0159),
  `PlayerInput` (owner's keys), `PlayerQuests` (quests, log 0179);
  `PlayerSave` (progress save format and sanitizing). `Regions` (where each place is, spawn points, who a gate admits),
  terrain per region: `CenterTerrain`, `UpperEast` (Noble Quarter, Priests'
  Hill), `Underworld` (the Undercroft hub, earth band), `Cave` (training cave
  off the Undercroft), `Barracks` (drill yard, General, Quartermaster; all on one island, log 0232),
  `Coast` (west of the barracks, workmen only: dock, piers, the Logging
  Isle; logs 0200-0202, 0208) with `Ocean` (waves and each stretch's rain from the server's clock, log 0215;
  drowning), `Boat` (server-simulated sailing boats) and `WorldResource`
  (things hit for drops, regrowing): `Timber` (the Logging Isle's trees,
  logs every 1,000 damage) and `OreRock` (the Quarry Isle's rare ore, log
  0211). `Market` (the merchants' dock
  stock, ore stock, work orders and booth orders on Merchants' Row; log 0205, 0209, 0211).
  Promissory notes stack in one slot (`note_12`, `Gear.note_count`,
  `PlayerInventory.add_notes`); the family strongroom is
  `PlayerInventory.vault` (swap indices from `VAULT_BASE`), saved in the
  family's progress (log 0212), with `heirlooms` / `heirloom_pending`
  (armor passed down at succession, `PlayerInventory.pass_down`, log 0216).
  The Blacksmith (`Npc` role "smith", `PlayerActions.upgrade`) upgrades
  gear to +5; upgrades live in the item string (`points_9+3`, `Gear.plus_of`).
  `Mission` (one squad's instanced battlefield) and `Missions` (server-side
  musters, pay, discharge); `Fortress` (the rangers' fortress raid, an
  instance with its own stormy sea via `Ocean.add_sea`, rowboats (`Boat`
  `rowed`), a winch and drawbridge, an enemy boat, lookouts and a back
  door; logs 0248, 0250, 0253). `Npc` (talkers, priests, healers; solid,
  log 0223; built from each terrain's `NPCS` data), `Elevator` (the underworld lift runs down a shaft
  cut from the terrain, capped by a hatch, log 0227), `HouseDoor` (chests), `Buildings`
  (house drawing: open, with rooms, logs 0188, 0222; `raised` mound data),
  `House` (a solid house, lawful or crooked, log 0222), `Projectiles`
  (thrown shots, server-decided, flown by every client; log 0242),
  `RangerCamp` (the rangers' secret island, log 0246), `RangerExam` (ranger
  school's instanced exam course, log 0245), `Mound` (floating
  ground: raised houses' organic islands, NPC daises; the road dips into a
  valley under each, `Buildings.smooth` curves, log 0226). Nothing in
  the plane is scenery (log 0221). `World.add_places` builds every fixed
  thing (terrain, mounds, houses, lifts, NPCs), for the game and tests. `Enemy`, `Pickup` (per-player loot), `NetSmoother`
  (client-side smoothing of server-simulated bodies).
- `scripts/abilities/`: one script per ability (`RushAbility`,
  `NoseDiveAbility`, `SpikeUpAbility`; the rangers' `VolleyAbility`,
  `ChargedShotAbility`, `DoubleJumpAbility`, held ones released, log 0244)
  extending `Ability`; `Abilities` (the registry, shop order, key slots:
  abilities are equipped, `PlayerStats.ability_slots`, log 0243) and
  `MoveSet` (one body's abilities, for players and Revolt bosses). Log 0107.
- `scripts/admin/`: admin commands typed into chat after `\` (log 0125):
  `AdminConsole` (parsing, help, who's an admin, short player ids) and one
  script per noun (`PlayerCommands` with its `players quests` sub-noun `PlayerQuestCommands`, `EnemyCommands`, `QuestCommands`, `ItemCommands` (log 0214), `ResourceCommands` (log 0217); plural nouns, log 0196). Roles: `profiles.role`, set only in
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
- `scripts/cutscenes.gd`: the birth and wedding cutscenes' lines (server
  content, logs 0168, 0171, 0172, 0180) and helpers for writing any
  cutscene, sent by `Net.play_cutscene` (which can run code once it ends)
  and drawn by `scripts/ui/cutscene_player.gd`, whose header has the
  format (log 0179). Read them all, quests' too, with
  `-s tools/tests/dump_cutscenes.gd`.
- `scripts/quests/`: `Quests` (the registry and step format, log 0179) and
  one script per quest, steps as data beside its cutscenes
  (`BootcampQuest`, log 0181; `RangerSchoolQuest`, log 0245, offered at
  level 20 rather than at birth). `scripts/world/player_quests.gd`
  (`PlayerQuests`, a PlayerShape part) keeps each player's progress (the
  account's, not the family's: saved by `SaveKeeper` to the `quests` table
  or `quests.json`, log 0183), counts goals, runs actions and syncs the
  HUD's tracker. Test:
  `-s tools/tests/test_quests.gd`.
- `scripts/shape_geometry.gd`: polygon outlines. `scripts/web_app.gd`: the
  web build's update-and-reload (log 0122; switches to a new build id on
  launch, log 0166). `scripts/build_info.gd`: the build id (commit, plus a
  hash of uncommitted changes), baked into exports by
  `addons/server_address`. `scripts/ui/`: palette, item slot,
  theme, HUD (its Tab panel's Purse page: chits and coins, log 0204; `MoneyIcon`), touch controls, chat box (and its admin terminal's
  `ConsoleCompanion`, imsdow, whose lines are in `imsdow.cfg` and animations are folders of text or picture
  frames in `assets/companion/<animation>/`, colored by
  `companion_pop.gdshader`; `tools/companion_ink.py` cleans pictures into
  ink; `tools/loading_screen.py` draws the web page's loading screen (the
  Priest, log 0197) into `web/shell.html`; logs 0138, 0141, 0143-0146), shape icon, stat bar, parchment background (stained only in the poor
  quarters, log 0190), atmosphere (foreground dust/light/fog), ink pass
  (the hand-drawn shader over the world: crosshatched fog, logs 0191, 0194), flat view
  (`FlatView`, `\view`: a Flatlander's eyes as vertical bars, rays through
  `FlatMap`, a picture of only the solid shapes and the sea,
  `flat_eye.gdshader`; logs 0238-0240, 0249; screenshots:
  `tools/record/flat_view_shots.gd`), menu (Offline / Online, log 0119; sidebar,
  picture and family panel, log 0185), the menu's hand-drawn look
  (`Sketch` line helpers, `SketchBox` style, `MenuScene` picture,
  `UiTheme.build_menu`), online login, Google sign-in button.
- UI is built in code from a bare root node; scenes stay minimal.
- Fonts: `assets/fonts/` (DejaVu subsets, log 0136; IM Fell English for
  the main menu, log 0185). The web build has no
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
- Coast test (gate, sailing, capsizing, drowning, trees, the market; prints
  BOAT lines for tuning): `-s tools/tests/test_coast.gd`. Screenshots of the
  coast, the Row and the purse (needs a window, not headless):
  `Godot --path . --resolution 1280x720 -s tools/record/shots.gd -- --no-hot-reload --out=<folder>`.
  Regimental armor at +0/+3/+5, the Blacksmith and the Quarry Isle:
  `tools/record/smith_shots.gd`, the same way.
- Ranger test (ranger school, the island, throwing recruits, the ranger
  stores, rations): `-s tools/tests/test_ranger.gd`.
- Missions test (painted skirmishers and archers, the fortress raid: rowboat,
  storm, lookouts and the alarm, climb, drawbridge, drowning out; prints
  STORM, BOAT and ROUTE lines; steps the sea's clock with the physics,
  `Ocean.test_clock`):
  `-s tools/tests/test_missions.gd`. Screenshots of the raid:
  `tools/record/fortress_shots.gd`, run like `shots.gd`.
- Route test (can a starting triangle still get where it must, through the
  solid world): `-s tools/tests/test_routes.gd`. Screenshots of the houses
  and islands: `tools/record/world_shots.gd`, run like `shots.gd`.
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
- **Run tests with `--fixed-fps 60`** (`Godot --headless --fixed-fps 60 --path . -s ...`):
  the same physics steps, without waiting for the clock (routes 8 s instead
  of ~80, the player test 4 s). Not `test_chat.gd`: its ping checks time
  real milliseconds (it's quick anyway). Run only the tests for what you changed.

## Code conventions

- Multiplayer is supported from the start: server-authoritative. Gameplay
  state changes happen on the server; clients send input. Single player runs
  as a local server. Don't optimize networking yet.
- Bump `application/config/version` in `project.godot` with any change an
  older client or server couldn't play with (RPCs, synced properties,
  content sent over the network). Clients and servers must match exactly
  (design log 0109). Never change the RPCs in `scripts/autoload/handshake.gd`.
- `docs/` has a `.gdignore` so Godot doesn't import it.
