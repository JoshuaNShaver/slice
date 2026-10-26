# Handoff: rangers, stages 4 and 5

Rangers are a ranged build for a multiplayer Flatland roguelite (Godot 4.5,
GDScript). Stages 1–3 are built and tested. This note covers what's left:

- **Stage 4:** Revolt rangers ("Painted skirmishers") in the three existing
  missions.
- **Stage 5:** the rangers-only mission, a fortress raid by sea.

Read `CLAUDE.md` first: it covers project rules, running, tests and logs.
Then read `docs/DESIGN.md` §2d (Rangers) and design logs 0241–0248. Logs
0247 and 0248 are the specs for these two stages.

## Ground rules (from CLAUDE.md, easy to miss)

- **Design log for every decision.** Use the next number (the last is 0248)
  and update DESIGN.md to match. Mark your own suggestions *Proposed*.
  Never rewrite an old log's decision.
- **Server-authoritative.** Clients send input; the server changes state.
- **Bump `application/config/version`** in `project.godot` for any change
  to RPCs, synced properties or network content. It's at 0.3.10 now and
  nothing has shipped since that bump, so you may not need another unless
  this ships separately.
- **Tests:** `Godot --headless --fixed-fps 60 --path . -s tools/tests/<test>.gd`
  (but `test_chat.gd` without `--fixed-fps`). Run only the tests for what
  you changed.
- **Godot binary:** `/Applications/Godot.app/Contents/MacOS/Godot`. After
  adding a `class_name`, run `Godot --headless --path . --import`.
- **Uncommitted work.** All of stages 1–3 and a lot of the user's own work
  are in the working tree, uncommitted. Don't commit unless asked.

## What already exists (use it, don't rebuild it)

| Piece | Where | Notes |
|---|---|---|
| Projectiles | `scripts/world/projectiles.gd` (`Projectiles`) | One node in the world. A shot is a dictionary passed to `throw()` or `throw_fan()`. The server decides hits; clients fly the shot themselves from one `_spawned` RPC. Its keys are listed in the file header. |
| Hostile shots | `Projectiles.throw({... "side": "hostile", "source": enemy, "only": peer})` | Hurt players and the army's soldiers. `source` credits hits to the enemy (`hits_landed`, `struck`). `lethal: false` stops at 1 health. Drawn in `Palette.REVOLT`. |
| Throwing enemies | `Enemy._ranged()` in `scripts/world/enemy.gd` | Give an enemy type a `"ranged": {"every": Vector2(min, max), "range": px, "keep": px, "damage": n}` entry. It backs off inside `keep`, holds position in range, closes in from further, and throws when it has line of sight. The `ranger_recruit` and `edric` types use it. |
| Bout limits | enemy data `"bout_hits"` | How many landed hits lose a quest bout (default 2). |
| Missions | `scripts/world/missions.gd` (`Missions`), `scripts/world/mission.gd` (`Mission`) | Instanced battlefields in slots far east (`Regions.MISSION_ORIGIN`). `Mission.TYPES` holds each mission's data. `Missions._revolt_for()` picks the enemies, `_deploy()` places them, and `_spawn()` spawns one. |
| Ranger check | `RangerSchoolQuest.trained_or_training(p)`, `p.quests.is_done("ranger_school")` | Use `is_done` to make the fortress raid rangers-only. |
| Boats | `scripts/world/boat.gd` (`Boat`), `World.launch_boat()`, Npc role `"boats"` | One boat per player. You lean into the sail to drive it; it capsizes past 105° and anyone aboard drowns (`PlayerActions.drown`). |
| Sea and rain | `scripts/world/ocean.gd` (`Ocean`) | Waves and each stretch's rain come from the server's clock. **It's tied to the coast** (see the stage 5 risk). |
| Instanced places | `RangerExam` + `World.open_exam()`, `Regions.exam_*`, `Regions.camera_rect()` | A recent example of a per-player instance: spawned through a MultiplayerSpawner, built the same on every peer, frees itself once its owner has been away for a while. The camera keeps to `Regions.camera_rect(pos)`. |
| Screenshots | `tools/record/ranger_shots.gd` | Needs a window. A `-s` script compiles before the autoloads exist, which leaves `Abilities.ALL` empty; the tool rebuilds it with `Abilities.ALL = Abilities._info_of_all()`. Copy that line into any new `-s` tool that uses abilities. |

## Stage 4: Painted skirmishers (log 0247)

**Spec.** The Colour Revolt fields rangers in recon, invasion and special
ops. These parts are *Proposed* and you may tune them:
- They keep their distance and throw a dodgeable tip every 2–3 s.
- Recon gets 1–2, invasion 4–6, and special ops trades two of its five
  bodyguards for skirmishers.

**Plan.**
1. Add a `"skirmisher"` type to `Enemy.TYPES` with `"paint": true` and a
   `"ranged"` entry. Base its health and damage on `rebel` (240 health) and
   `agitator` (620), scaled by level band. A single type at about 300
   health works for recon. For invasion and special ops, either add a
   tougher variant or pass `strength` to `Missions._spawn()`; both already
   work.
2. In `Missions._revolt_for()`, add the skirmishers per mission. Watch for:
   - Recon's Captain huddle (`huddle` in `_deploy`). Huddled enemies don't
     chase, and `leash` keeps them near. A skirmisher in the huddle should
     probably still throw at anyone within range. Check that `_ranged()`
     works with `leash`: today `_nearest_target()` drops a target past the
     leash, so it won't throw at all.
   - Spread placement: `_deploy` places non-boss enemies at a random
     0.42–0.9 of the field's width. Skirmishers may want the back half.
3. Optional: the recon soldier's hints (`NOBLE_HINTS` and so on) could warn
   about throwers.
4. **Tests.** There's no mission test file. Either add one, a bare world
   with `Missions` and a stand-in for `World` (see `tools/tests/ranger_checks.gd`
   for the pattern), or extend `ranger_checks.gd`. At minimum:
   - each mission's enemy list includes skirmishers;
   - a skirmisher throws at a player in range;
   - its shots hurt soldiers (`side: "hostile"` already includes army
     enemies).

Small stage. The throwing behaviour and shots are done.

## Stage 5: the fortress raid (log 0248)

**Spec (accepted by the user).**
- A rangers-only mission from the General, for up to 4 players.
- A **boatman** at the start spawns a slightly bigger boat (two pontoons,
  or a rowboat) that **he rows once spoken to**. All players can ride it,
  or each can spawn their own.
- Cross the sea **in a storm** to an enemy fortress, leave the boat,
  **climb the walls**, cross the top of a wall, and **let down the gate**
  at its end.
- An army troop then charges in, and you fight the **fortress commander**,
  a boss.
- **Capsizing ends the mission for that player.**
- *Proposed:* recommended level 20; skirmishers and melee rebels hold the
  wall top; pay 250 chits; the usual 1-in-5 discharge with a marriage
  certificate (log 0092; `Missions.DISCHARGE_CHANCE`).

**The big risk: the sea is tied to the coast.** `Ocean` and `Boat` assume
the one western sea:
- `Ocean.is_sea()` uses `Coast.ground_y()`.
- `SHORES` and `STRETCHES` are coast x-positions.
- `_draw()` clamps to `Coast.WEST_X` … `Coast.SHORE_EDGE`.
- `PlayerMotion.integrate()` calls `Ocean.drowns()` and `Coast.hold_back()`
  at every position.

**Watch out:** `Coast.ground_y(x)` clamps to its edge points, so far west of
the coast `is_sea()` is true. Don't put instances at large negative x, or
players will drown on dry land. The ranger camp and the exams sit at
x 23,000–53,000 for that reason.

The instanced fortress needs its own stretch of sea. Options, roughly in
order of preference:
1. **Generalize `Ocean` into sea regions.** Make it a registry of
   `{x0, x1, level, waves, stormy, ground: Callable}`, with the coast's sea
   as one entry and each fortress instance adding its own. Then `drowns`,
   `surface_y`, `rain_at` and drawing look up the region by x. This is the
   most work but keeps one water model. Boats would "just work", but check
   `Boat` for direct `Coast.*` uses.
2. **A separate `FortressSea`** inside the mission instance that copies the
   needed `Ocean` functions, with `Boat` taking a water provider. Less
   coupling to untangle, but two water models.
3. **Run the crossing on the real western sea.** Rejected: it isn't
   instanced, so squads would share it, and the fortress would have to be
   a fixed place.

Make this choice first and record it in a log (*Proposed*). It decides most
of the rest.

**Other pieces.**
- **Mission type.** Add `"fortress"` to `Mission.TYPES`. It can't use
  `Mission`'s rolling-hill ground: it needs a sea, then the fortress. The
  likely shape is a new instance class (like `RangerExam`: hand-built
  layout, the same on every peer), spawned in a mission slot or its own
  slot range.
  - `Missions` assumes a `Mission` node, using `node.ground_point()`,
    `node.width`, and the `_deploy` placement. Either give the fortress
    class the same interface or branch `_deploy` on type.
  - The General's orders panel lists `Mission.ORDER` (see
    `Hud._build_orders`). Hide or refuse the fortress for non-rangers:
    check `p.quests.is_done("ranger_school")` in `Missions.request()`.
- **Boatman and rowed boat.** Add a new Npc role, or extend `"boats"`. The
  rowed boat:
  - is bigger, with room for 4 standing on its deck;
  - is driven by the NPC rather than by leaning: steady forward speed once
    spoken to, maybe holding position until someone presses use;
  - still pitches on storm waves, so a passenger can be thrown off.
  
  Likely approach: a `Boat` variant (or a `rowed` flag) whose
  `_integrate_forces` applies drive without needing a leaning player, with
  a wider hull. "Each spawn their own": allow one per player, as
  `World.launch_boat` does (it removes your previous boat).
- **Capsize = out of the mission.** Today drowning runs
  `PlayerActions.drown()`: the bag is lost, a cutscene plays, and you wake
  on the coast's shore. For the raid it should send that player home and
  forfeit their pay instead, and probably not empty the bag. Branch on
  whether the player is in a fortress instance. `Missions` already handles
  "left early forfeits pay" (`_watch`, membership), so drowning can remove
  them from the instance and teleport them to the barracks.
- **Storm.** Rain and big waves throughout the crossing. Logs 0215 and 0218
  have the existing rain and wave rules: rain doubles waves in the narrows.
- **The climb.** A wall face with ledges, platforming like the exam
  (`RangerExam.LEDGES` style). For tuning: a 50°+ triangle's standing jump
  lifts its lowest point ~107 px; a rolling jump ~250 px with ~150 px of
  run.
- **Wall top and gate.** Skirmishers and melee rebels on the walkway. The
  gate is a solid piece in the fortress that removes its collision when
  "let down". The trigger is up to you: the use key at a winch at the end
  of the wall (an Npc-like interactable, or a `World._nearest_interactable`
  candidate), or a goal like killing the wall's guards. Whatever you pick,
  it must sync to clients (a synced property, or the server freeing a
  spawned node).
- **Troop and boss.** Once the gate drops, spawn soldiers (`"soldier"` type,
  `role = "seek"`) charging through, and a new boss type for the commander:
  `"boss": true`, `"moves": true` and `"gear"` like `captain` and
  `chromatistes`. It could also use `"ranged"`. Hook it into
  `inst.boss` / `boss_down` so the discharge chance applies.
- **Pay and victory.** 250 chits on the boss's fall, as `_win` does now.
- **Tests and screenshots.** A test like `ranger_checks.gd`:
  - only rangers can take the orders;
  - the boatman's boat moves once spoken to;
  - capsizing removes that player from the mission without the coast's
    drowning;
  - the gate opens;
  - the boss's fall pays.
  
  Also add screenshots to `tools/record/ranger_shots.gd` (the crossing,
  the wall, the gate).

Stage 5 is large. Suggested order:
1. The sea decision and refactor.
2. The fortress instance (layout only) and the mission plumbing, rangers
   only.
3. The rowed boat and the capsize rule.
4. Wall enemies, the gate, the troop and the boss.
5. Tests, screenshots, design logs and DESIGN.md.

## Open questions to raise with the user (don't guess these)

- How is the gate let down: a winch you use, or clearing the wall?
- The commander's name and shape (the Revolt's bosses are irregular
  polygons, log 0068).
- Does the boatman wait for everyone, or row as soon as anyone speaks to
  him?
- Should capsizing also cost the bag, as drowning on the coast does, or
  only the mission?
