# Flatland (working title): Design Doc

A multiplayer roguelite set in the world of Edwin Abbott's *Flatland* (1884).
You are a polygon in a 2-D world viewed from the side. Rank is your number of
sides. You fight, explore procedural dungeons, collect gear and trinkets, and
marry so that your heir is born with one more side. Die without an heir and
your lineage falls back to a triangle.

- **Engine:** Godot 4.5 (Forward Plus)
- **Inspirations:** Realm of the Mad God and Borne Again (multiplayer, fast
  leveling, permadeath with meta currency), Risk of Rain (stacking trinkets),
  Rogue Legacy (lineage), Spelunky (procedural levels)
- **Decision history:** `docs/design-log/`. This doc is the current state, and
  the logs record why each part is the way it is.

---

## 1. World

The whole world is one continuous side-view plane, like a drawing on paper.
Gravity pulls **south** (screen down), as in the book.

| Direction | Region | Who goes there |
|---|---|---|
| Center | Respawn hub | Everyone (but irregulars) |
| West (left) | The barracks and drill yard; missions go to the front (logs 0061, 0067–0072, 0077) | Triangles (soldiers), and any higher rank (log 0073) |
| East, up an elevator | The Noble Quarter (log 0054) | 4+ sides, regular |
| Further east and north, up a hill | The Priests' Hill and the Temple of the Circle (log 0055) | Same as the Quarter; the sanctum is for circles (10+ sides) |
| North | Undecided (log 0062) | |
| South, down an elevator | The underworld: the Undercroft and the training cave | Regulars with 5+ sides may visit (log 0066); irregulars are confined here |

Shape gates access, and each rank keeps every activity below it (log
0073): triangles go to war (and, near equilateral, trade and gather, log
0074, proposed), squares gain the college (log 0075), circles the
dimension puzzles (log 0076). Exact gates per region are TBD (see Open
questions).
Places and spawn points live in `scripts/world/regions.gd`.

Dungeons and mazes are **procedurally generated**.

**NPCs (log 0052):** every NPC serves some shapes and refuses others, fixed
per NPC (never a dice roll). Overworld NPCs serve regulars; most underworld
NPCs refuse them. Press interact (E) by an NPC, elevator or door to use it.

**Houses (logs 0053, 0060, 0059):** every overworld house is a regular
pentagon, as the book's law requires: roof to the north, men's door on the
east, women's smaller door on the west, no windows. They are NPC homes and
scenery. Underworld houses break the law: crooked, lopsided, even
triangles and squares.

**The Center (log 0019):** a plaza. The land sinks west to the open
barracks gate and rises east (a 35° slope) to the elevator up to the Noble
Quarter. Jump-through ledges climb north; *proposed (log 0062):* they stay
as platforming that later-game gear may be needed to finish. The old south
hatch is the elevator down. The priest, a merchant, a workman and a
shopkeeper (triangles) live here.

**Elevators (logs 0054, 0066):** guards at both ends check your shape.
- **Down to the underworld:** regulars with 5+ sides (log 0066). Any
  regular may ride up; irregulars never can.
- **Up to the Noble Quarter:** regulars with 4+ sides.
- The ride carries you through the rock in a cage, a few seconds long.

**The Noble Quarter (log 0063, proposed layout):** a plateau high above the
Center's east end, its cliff too tall to jump. Pentagon houses, a lawyer
(square) and a gentleman (hexagon). **The Physician** (a pentagon) heals
regulars anywhere in the quarter. **Your house** is here (§5).

**The Priests' Hill (log 0063, proposed layout):** east of the quarter,
terraces of about 15° (decagons can stand on them) climb to the **Temple of
the Circle**. **The High Priest** marries, and heals regulars on the temple
grounds; an acolyte (12-gon) stands by. The sanctum (circles only) is sealed
for now.

**The underworld (logs 0051, 0052, 0059):** almost self-contained, since
irregulars can't leave. Its hub is **the Undercroft**, under the Center:
- Irregulars spawn here, and the home key (C) brings them here.
- **The Bonesetter** heals irregulars anywhere in the Undercroft.
- **The Hedge Priest** (a circle who failed inspection) marries irregulars.
- **The Fence** deals with anyone, regulars at a markup (no stock yet).
- Its other people refuse regulars. East is sealed for now.
- An irregular parent can have a regular heir (§5); that heir is sent up to
  the Center.

**The training cave (logs 0027, 0051)** opens off the Undercroft's west end.
Three rooms,
each a different chalk color, get harder going in:

| Room | Enemies | Levels | Drops |
|---|---|---|---|
| Rose Hollow | bandits (irregular squares) | 1–7 | rose armor (tier 1) |
| Mint Gallery | brutes (irregular pentagons) | 7–14 | mint armor (tier 2) |
| Lilac Deep | zealots (irregular hexagons) | 14–20 | lilac armor (tier 3) |
| Back of the Lilac Deep | **the Pretender** (boss) | 20 | gilded gear (tier 4), a marriage certificate and a potion, always; 1 in 20 a blessed certificate too (§5) |

Every cave enemy also has a 10% chance (boosted by luck) to drop a healing
potion (§2b).

Enemies chase players inside their own room only, and respawn after 12 s
(the boss after 90 s). *Proposed* stats are in `scripts/world/enemy.gd`.

**The barracks (logs 0061, 0067–0072, 0077):** west of the Center through
an open gate (`scripts/world/barracks.gd`). East to west:
- **The drill yard (log 0072):** straw dummies and sparring partners for
  levels 1–5 (spar until about 3–5). Partners can't bring you below 1
  health. It drops **leather** gear.
- **The Quartermaster** (equilateral) sells bronze, iron and steel,
  provisions (§2b) and ability drills (§2c), for combatant pay. **The Surgeon** heals on request.
- **The General** (a pentagon, proposed) gives missions; squads muster
  beside him for 10 s. A popup shows the timer, and the squad leaves early
  once everyone presses **Ready** (log 0081, proposed). After a victory,
  the squad goes home in 6 s, or at once for anyone who presses Ready.

The army fights the **Colour Revolt** (log 0068): rebels in loud vermilion
paint. Its bosses are irregular polygons that fight as if wearing a full
set of underworld gear. Missions are **instanced** (`Mission`,
`Missions`): each squad gets its own battlefield far from the world. They
pay XP per kill and **combatant pay** on success, no loot. Levels are a
guide; you may go under-leveled. Leaving early forfeits the pay.

| Mission (log 0070, proposed) | Levels | Squad | Revolt | Soldiers | Boss | Pay* |
|---|---|---|---|---|---|---|
| Recon | 5–10 | up to 4 | 3–5 rebels; secretly 1 in 5 a Painted Noble (pay ×2) | 1 | secretly 1 in 10 (luck helps): a half-strength Captain (pay ×5) with a huddle (below) | 25 |
| Invasion | 10–20 | up to 8 | 20–24 rebels and agitators, and 1–3 painted gentry (2× strength, use moves; log 0091) | 10 | none | 80 |
| Special ops (assassination) | 20 | up to 2 | 5 bodyguards | none | always two: Chromatistes (gilded-buffed) and a Captain guarding him | 200 |

Recon's extra foes are never announced (log 0088); the squad's soldier
hints at them in a speech bubble once you're on the field. **The recon
Captain (log 0089)** brings 6–10 rebels, a Painted Gentleman (pentagon) and
a Painted Noble (hexagon), all huddled round him: none of them chase, they
fight whoever comes within reach. When he falls, they chase. Once he's
spotted, a popup offers **Report back** for 20 s: home at once for double
pay.

**Revolt bosses' moves (log 0089):** Captains and Chromatistes use the
players' abilities (§2c) every 3–5 s: spike up when you're close, a nose
dive onto you from middle distance, a rush from further out. Their hits do
double damage mid-move. A player's spike up can't throw a boss. Invasion's
gentry use them too, and every move is telegraphed: the fighter shouts an
insult in a speech bubble, then moves 0.8 s later (log 0091).

Bringing down a Revolt boss (recon's Captain, special ops) earns each
squad member a **1 in 5** chance (luck helps) of a discharge with a
marriage certificate, which the General gives back at the barracks, like a
promotion (logs 0067, 0092). Invasion has no boss: it's for levels and pay. Soldiers wear bronze; players pass through them. On recon
the soldier orbits you when there's nothing to fight: it rolls past you,
waits for you to move, then rolls past the other way (log 0078). Soldiers
get around by jumping, like a player, and the further back they are the
harder they roll and jump (logs 0079, 0080); once engaged they just
fight. On invasion they hunt the Revolt anywhere on the field (log 0079).

**Priests** (circles) marry you (§5): the priest on the Center plaza and the
High Priest at the temple for regulars, the Hedge Priest for irregulars.

## 2. Player and movement

- You are a regular polygon (or an irregular one, see §5).
- **Left / right:** roll. **Space:** jump. **Up / Down / Shift:** nose
  dive, spike up, rush (§2c, once learned). **E:** interact. **G:** pick up.
  **F:** drink a potion. **1–5:** quick-use slots (§4). **C:** home
  teleport (§2b). **Tab:** character
  sheet. **Esc:** menu.
- **All controls are rebindable (log 0035):** each is a named input action
  with up to two keys, changed in Esc > Controls (saved per machine).
- **Touch (log 0122):** on a touch screen, a stick under the left thumb
  rolls (analog); bottom right, a big **Jump** with the owned abilities in
  an arc around it, plus **Use** / **Take** only while something is in
  reach; top right, **Drink**, **Home**, **Bag**, **Menu**. Hints name
  these buttons. A phone held upright is asked to turn sideways. Open:
  dropping items by touch, HUD text size on phones.
- *Proposed:* a regular n-gon holds still on slopes up to about 180°/n, so
  triangles grip steep ground and many-sided shapes slide. Terrain can gate
  shapes without doors.
- **Feel: tumbly and gymnastic (log 0020).** Holding a roll key builds speed
  over a few seconds, and downhill momentum can push you past it. Shapes
  are a little bouncy and keep their spin.
- **Bounce jumps:** jump again as you land. Off a face: higher than a normal
  jump. Off a corner: higher still, and you flip.
- **Jumps are free (log 0087).** Energy is only for abilities.
- *Proposed (log 0019):* shapes are physics polygons simulated by the server,
  so the 180°/n grip comes from the geometry. Players pass through each
  other. In mid-air you drift sideways but don't turn (see Open question 5).

## 3. Combat

- Mario-style: jump and land on an enemy. **Only corners deal damage.**
  Landing on a flat face does nothing.
- **Damage per corner hit = 180° − corner angle.** For a regular n-gon this is
  360/n:

  | Shape | Corner | Damage/corner |
  |---|---|---|
  | Triangle | 60° | 120 |
  | Square | 90° | 90 |
  | Pentagon | 108° | 72 |
  | Hexagon | 120° | 60 |
  | Octagon | 135° | 45 |
  | Decagon | 144° | 36 |

- That is the base. Actual damage is scaled by level and force (§4b): a
  level 1 triangle corner does 60, about 178 at level 20.
- **Multi-hit (leaning yes):** more sides means more corner hits as you roll
  over an enemy. A full turn always totals 360 damage, whatever the shape.
  Few sides hit in big stomps, many sides in small hits.
- *Proposed (log 0027):* hits come from contact. A corner that strikes an
  enemy at 70+ px/s deals its damage, whether you land on the enemy or roll
  into it. Enemy corners hurt you by the same rule (flat damage per enemy
  type, minus rigidity). The same pair can't hit again for 0.3 s, and after
  being hit you can't be hit again for 0.6 s.
- **Damage numbers (log 0046):** every hit's damage floats up from the
  target and fades, for all players to see. Ink for damage to enemies, red
  for damage to players.
- **Critical hits (log 0047):** each player corner hit has a 10% chance
  (raised by luck; irregulars start at 20%) to deal double damage, shown
  larger, in gold, with a "!". Enemies don't crit.
- High ranks can bring triangles to fight for them.
- All classes may use the same combat, or classes may get distinct combat.
  Undecided.

## 4. Gear and leveling

- All classes equip **armor**. Collected **trinkets** stack, Risk of Rain style.
- Armor never changes your outline (it would change your corner angles and
  so your damage). **Shapes are plain (log 0069):** unarmored is an ink
  outline with an uncoloured fill, and overworld armor is told apart by
  crosshatch patterns. Colour comes only from the underworld (contraband)
  and the Colour Revolt.
- **Leveling:** max level 20, reached in about 30 minutes. After that you earn
  **renown**, the meta currency.
- *Proposed (log 0028):* kills give XP to everyone who hit the enemy. Level
  n → n+1 costs 20 + 15 × (n − 1) XP (about 2,950 for level 20 in all).
- **Gear slots (log 0036).** The book has no equipment, so the five slots
  come from what it does have. Each gives one stat and never changes your
  outline:

  | Slot | What it is | Gives | Shows as |
  |---|---|---|---|
  | Points | caps on your corners | force | dots on your corners |
  | Plating | armor | rigidity | a crosshatched inner band (log 0069) |
  | Pigment | contraband colour (Colour Revolt) | vigor | a tint on your fill |
  | Eye | a lens for sight recognition | luck | nothing yet |
  | Voice | a pipe for your cry (an ability slot later) | mettle | nothing yet |

- **Military tiers (logs 0071, 0072, 0077):** leather (drill yard drops),
  then bronze, iron and steel (bought: 30 / 90 / 240 pay* each). *Proposed:*
  +2 / 4 / 7 / 10, plating +3 / 6 / 10 / 15, so steel equals lilac. No
  pigment slot (colour is contraband), so no military sets.
- **Tiers (log 0029):** each cave room drops the next tier: rose 1, mint 2,
  lilac 3, the Pretender's gilded 4. *Proposed:* +3 / 6 / 10 / 15, plating
  +4 / 9 / 15 / 22. Loot is per player: each player who hit the enemy gets
  their own roll (15% for room enemies, boosted by luck), for a random slot.
- **Full sets (log 0040):** all five slots in one tier add that tier's own
  bonus. Mixed tiers give nothing. **The bonus is secret (log 0045):** item
  descriptions don't mention it; you learn it on completing the set. A
  full set shows as a halo in its color:
  rounded, softly glowing, and lifted a little off the outline.

  | Set | Bonus |
  |---|---|
  | Rose | +15 force |
  | Mint | +15 torque (speed) |
  | Lilac | +15 rigidity (defense) |
  | Gilded | +15 vigor (+150 health) and +15 luck |
  | Leather (log 0085) | +10 force |
  | Bronze | *proposed* +10 vigor |
  | Iron | *proposed* +10 rigidity |
  | Steel | *proposed* +10 torque |

  A military set is its four slots (points, plating, eye, voice); pigment
  doesn't count.

- **Bag (logs 0036, 0043, 0044):** 10 slots, plus 5 **quick-use slots**
  (keys 1–5) that are bag slots too. Nothing is taken by touch. The pickup
  key (G) grabs the nearest of your items, filling the bag before the quick
  slots. **Drag and drop** moves items between any slots. **Double-click**
  an item, or press its quick-use key, to use it (wear gear, drink a
  potion, eat). Right-click drops an item. Drag gear onto a character-sheet slot
  to wear it, or off to remove it (double-click also removes it). Only the owner can take an item off the ground, and it
  vanishes after 90 s.
- **Stat books (log 0024):** rare consumables permanently raise one stat,
  like Realm of the Mad God's potions. *Proposed:* forbidden books such as
  treatises on color theory (color is banned after the book's Colour Revolt).

## 2b. Healing and home (logs 0033, 0034)

- **Home teleport:** C sends you home at once, from anywhere, with no
  cooldown (like Realm of the Mad God's Nexus key). Home is the Center, or
  the Undercroft for irregulars (log 0059).
- **Healing:**
  - **Healers** heal you in full, for free, while you are in their area, if
    they serve your kind, and say something: the priest in the Center, the
    Physician in the Noble Quarter, the High Priest on the temple grounds,
    the Bonesetter (irregulars only) in the Undercroft. You can also ask
    them with E.
  - **Passive regen (log 0037)** everywhere: *proposed* 0.5% of max health
    per second in combat, 2% out of combat (5 s without hitting or being hit).
  - **Healing potions (log 0037)** restore *proposed* 40% of max health.
    Drink with F or by clicking one in the bag; not at full health.
  - **Provisions (log 0084)** are food the Quartermaster sells for pay.
    A meal heals over 8 s; eating more adds to what's left. *Proposed:*

    | Food | Heals (of max health) | Price |
    |---|---|---|
    | Hardtack | 20% | 3 pay |
    | Cheese | 35% | 6 pay |
    | Salt pork | 50% | 10 pay |

    Eat by double-clicking or a quick-use key; not at full health.

## 2c. Abilities (log 0086)

Bought once from the Quartermaster for pay; each use costs 50 energy. An
heir starts with none. *Proposed:* prices, keys and numbers. Each ability
is one script in `scripts/abilities/` (log 0107).

| Ability | Key | Price | What it does |
|---|---|---|---|
| Rush | Shift | 40 | Sideways speed and spin ×5, on the ground or in the air |
| Nose dive | Up / W | 60 | A jump at 3.5× jump speed (rises over 3 triangle heights, clearing enemies); coming down, your sharpest corner turns to point down and gravity pulls 2× |
| Spike up | Down / S | 80 | A face flat on the ground, sharpest corner up, held 1 s. Hostile enemies within 260 px are thrown up, helpless, and come down on it |

## 4b. Stats (logs 0021–0023)

Realm of the Mad God scaling. All stats are 0 at level 1. Each level adds a
random 1–2 to vigor, mettle, force and torque, about 3x growth by level 20.
Values marked * are proposed tuning.

| Stat | Gives | Level 1 → 20 |
|---|---|---|
| Vigor | Health = 200 + 10 per point | 200 → ~480 |
| Mettle | Energy regen = 5/s* + 0.35/s* per point (pool is always 100) | 5 → ~15/s |
| Force | Corner damage = (180° − corner) × 0.5* × (1 + 0.07* per point) | triangle 60 → ~178 |
| Torque | Top spin and spin build-up × (1 + 0.07* per point) | 1x → ~3x |
| Rigidity | Armor only, never levels. Subtracts flat from each hit; a hit always does at least 15%* | 0 |
| Luck | Good-outcome chances × (1 + luck/20), so 20 doubles them (log 0049). Rolled at birth (0–10*), irregulars +20, never levels; gear adds on top | 0–10 (irregular 20–30) |

- **Energy** pays for abilities, 50 each (§2c). Jumps are free (log 0087).
- **HUD (log 0026):** top left, your shape, level, health and XP bars.
  Bottom right, the 1–5 quick-use slots over a 5×2 bag (on touch, log 0122:
  the quick slots at the bottom center, the bag only while a panel is open). **Tab** opens the character sheet
  (equipment, stats); **Esc** the menu (players here, Controls, Leave). Top right is
  for currencies: **pay** (log 0071), kept by heirs (log 0077, proposed). **Energy** is 2 pips over your own shape, one per
  ability use, faded while full. Other players show a small health bar under their
  name.
- **Speech and thoughts (log 0082):** NPC lines appear in a bubble above the
  speaker, with a dashed line to them. Your own news (level up, pickups)
  and unattributed lines appear in a thought cloud beside you. Tooltips are
  see-through parchment.

## 5. Lineage

- **Goal of a life:** produce an heir.
- **Marriage certificates** have a chance to drop from **special events**: area
  bosses, dungeons, mazes and others. The cave's boss always drops one.
  Triangles may earn theirs by bringing down a Revolt boss (1 in 5, logs 0067, 0092);
  squares will earn them at the college without combat (log 0075).
- **Redeeming a certificate** at a priest (press E nearby) produces an heir
  with **+1 side** (log 0030). The heir takes over at once and starts fresh:
  level 1, no gear. Only the family carries on, plus spare certificates,
  potions and provisions.
  - **House (logs 0041, 0054, 0064):** once a family reaches a square, it
    gets a house with chests for storage, in the Noble Quarter. Press E at
    its east door to open your chests and drag items between them and the
    bag. *Proposed:* 20 slots; everyone uses the same door, each sees their
    own chests; saved by the server with the account (log 0112). Stored gear carries over to later heirs, so
    only square-or-better runs benefit from past runs' gear; triangle runs
    start with nothing. The chests belong to the player and outlive the
    family (log 0042): a new family gets them back on reaching a square.
  - **Triangles (log 0031):** only an **equilateral** triangle has a square
    heir (the book's rule). A new family's triangle is isosceles with a
    **45° apex**; each heir's apex is **5° wider** (50°, 55°, then 60°), so
    the 3rd heir is equilateral.
  - **Blessed certificate (log 0032):** a rare boss drop (1 in 20). Redeemed
    by a triangle, the heir is born equilateral at once. *Proposed (log
    0039):* it drops alongside the normal certificate, skips the irregular
    roll, also cures an irregular triangle, and works as an ordinary
    certificate for anyone else (who uses ordinary ones first).
  - **Irregular roll:** 1 in 10 chance the heir is **irregular**. Irregulars
    are confined to the underworld and cannot enter the overworld. Every
    heir rolls except an equilateral's, which is always a regular square
    (log 0096).
  - **Irregular triangles (log 0096)** climb the apex too: 45°, +5° each
    heir, up to 60°, drawn with the top off to one side. The heir's apex
    widens either way; a regular roll at 60° makes it equilateral.
- **Dying without an heir ends the family.** You must create a new one.
  Since the heir takes over at once, any death ends the family.
- **New families** pick their starting triangle (logs 0050, 0065):
  **isosceles (45° apex)** or **irregular**. Equilateral is earned by
  climbing, not picked.
- Past octagon you keep gaining sides. **10+ sides counts as circular: a
  priest.**
- **Past decagon, marriages don't always produce an heir** (the book's
  highest ranks struggle to have heirs). Rate TBD.

## 5b. Main menu and saves

- **Offline or Online (log 0119):** two modes, remembered. Offline is a
  local server with no network; Online joins the game's server
  (`online/server_address` in `project.godot`; on desktop
  `-- --server-address=` or `SLICE_SERVER` points elsewhere, for dev or
  LAN). No hosting from the menu; a server runs with `-- --server`.
- **Sign-in screen (log 0120, proposed, built):** Online connects at once
  and shows one card per step: reaching the server, can't reach it (Try
  again), "Sign in with Google" (Google's white button and G), finish in
  the browser. Signed in: "Signed in as <username> · Sign out" above the
  slots.
- **Usernames (log 0123):** a first online sign-in picks a username (3–16
  letters, numbers or `_`, unique ignoring case, set once) before the
  slots. The server keeps it in `profiles`; players never see an email.
- **3 family save slots.** Each slot: create a new family, play, or delete.
- **Saved progress (log 0038):** a family save keeps the lineage and the
  current heir's level, XP, stats, bag and worn gear. The server still
  caps anything out of range before restoring it.
- **The server owns saves (logs 0097, 0112, proposed, built):** all player
  data (3 family slots and the chests, per account) is loaded and saved by
  the server through one storage interface (`SaveStore`). Clients never
  send their own save. Offline and a LAN host's own player use this
  machine's files (`user://families/`, `user://chests.json`), as before.
  LAN joiners and a dev server's players log in with a device id; their
  saves live on that server. An online server uses Supabase (log 0114):
  tables `families`, `chests` and `profiles` keyed by the Supabase user, readable and
  writable only with the server's secret key.
  A dedicated server's `SAVES` setting picks `local` or `supabase` (log
  0117); unset, it uses Supabase when its settings are there.
- **When it saves (log 0113, proposed, built):** checked every 3 s; level,
  bag, gear, abilities and chests saved at once (at most every 10 s), XP
  and pay within 45 s; leaving, dying and marrying at once.
- **Accounts (logs 0098, 0105, 0115, proposed, built):** online play needs a
  Google login (Supabase Auth). Supabase tables and auth settings live in the
  repo and deploys apply them. The server sends the project URL and
  publishable key; the client logs in by PKCE (desktop: system browser and a
  `127.0.0.1` callback; web: page redirect, untested) and keeps the session,
  so it logs in once. The server checks the token with Supabase on each join.
  An account is online in one place per server; a new login takes it over
  and sends the older one away (log 0128, proposed). Offline needs no login.
- **Online slots (log 0116, proposed, built):** joining logs in first, then
  shows the account's 3 slots from the server; founding, deleting and
  playing are requests to the server. The menu shows who is logged in and
  "Log out".

## 6. Women (lines)

As in the book, women are straight lines.
- Bumping into one **damages you**.
- Hitting one at **high velocity kills you**.

(By the damage formula, a line's end has a 0° corner, so 180 damage.)

## 7. Multiplayer

- Online multiplayer like Realm of the Mad God / Borne Again. **Supported from
  the start, not optimized yet.**
- *Proposed architecture:* server-authoritative, using Godot's high-level
  multiplayer (WebSocket, `MultiplayerSpawner`, `MultiplayerSynchronizer`). Players
  send input; the server runs the simulation. Write gameplay code so a single
  player is just a local server with one peer.
- **Smoothing (logs 0093, 0095):** clients draw other players and enemies a
  little behind (60 ms), blended between server updates; your own shape uses
  the newest update. When updates run late, bodies keep moving at their last
  velocity (up to 100 ms) and corrections fade in rather than snap. No
  client-side prediction yet.
- **Clients (log 0099):** the web build is the main online client,
  installable on phones as an app (PWA, landscape; log 0122). Turned away
  for its version, it loads the newest build and reloads. Otherwise a new
  build downloads in the background and is used from the next launch
  (log 0127, proposed).
- **Transport (log 0110, proposed, built; changes 0099):** WebSocket for
  every client, desktop and web, on TCP 24680; ENet dropped. A browser
  can't host. A server address may be a host, a host:port, or a full
  `ws://` / `wss://` URL.
- **TLS (log 0118):** players join `wss://flatland-online.duckdns.org`
  (free DuckDNS name). Caddy on the VPS serves 443 with a Let's Encrypt
  certificate and passes WebSocket to the game on `127.0.0.1:24680`; the
  game port is closed to the internet. GitHub variables `SERVER_DOMAIN`
  and `SERVER_PORT` set both.
- **Version check (log 0109, proposed, built):** the version is
  `application/config/version` in `project.godot`, shown on the main menu.
  A joining client says hello with it; a mismatch is turned away with
  "This server runs version X; you have Y. Please update." Bump it with
  any change an older client couldn't play with.
- **Hosting (logs 0103, 0104):** game server on a Hetzner VPS. Manual
  GitHub Actions create, configure and deploy it; all keys are GitHub
  secrets (`deploy/README.md`).
- **Web client (log 0121):** at `https://flatland-online.duckdns.org/`,
  served by the same Caddy (WebSocket upgrades go to the game, everything
  else is the client). Each deploy exports it on the server from the same
  commit, so client and server always match. itch.io, if used, only links
  here.
- **Content as data (log 0101):** the server owns content (items,
  abilities, prices, shops, NPCs, text) and sends it on joining; the
  client owns presentation (theme, HUD, rendering).
- **Before public hosting (log 0100):** split `PlayerShape` into
  components (done, log 0106), version check, accounts and server-owned
  saves, then the web build.
- **Chat (log 0124):** Enter (or Chat on a touch screen) opens a typing
  line. Lines reach everyone in the same part of the world (overworld,
  underworld, or one mission; proposed), in the chat log and a bubble over
  the speaker. One line, 160 characters, 5 lines per 5 s. With keys the
  log sits bottom left and fades; on a touch screen it sits top left with
  the typing line on top, clear of the phone's keyboard.
- **Admins (log 0125):** `profiles.role` is `player` or `admin`, set only
  by a database update. Admins type commands into chat:
  `\<noun> <verb> [words] [--flags]`, e.g. `\player list`,
  `\player get 3`, `\player set level 11 --id 3`, `\player levelup 2`;
  `\help` lists them. Offline and a host's own player are admins; a
  dedicated server with `--dev-admins` makes everyone one (tests, dev).
- **Graphics settings (log 0094):** in the in-game menu: max framerate and
  High / Low. Low drops the atmosphere and background stains and renders at
  1280x720, scaled up. Saved per machine.
- **Window shape (log 0126):** the game fills the window; 1280x720 is the
  smallest view, and a wider or taller window shows more world, never black
  bars. Loading screens show the game icon on parchment.

## 8. Art direction

- **Palette:** pastel chalk colors, a fixed set. The overworld is mostly
  uncoloured (colour is banned, log 0069); colour returns a little in the
  underworld and loudly on the Colour Revolt.
- **Outlines:** dark sepia ink, so pastels stay readable on parchment.
- **Background:** parchment with ink stains in parallax layers moving at
  different speeds, giving depth as you roll left and right.
- **Underworld (log 0056, proposed, built):** chalk on slate. Dark ground, pale
  chalk outlines, the same pastel fills, fading in down the hatch shaft.
- **Foreground atmosphere (log 0057):** a subtle layer of dust, light or
  fog in front of the world in every region (`scripts/ui/atmosphere.gd`).
  *Proposed:* faster than the camera, client-only, under the HUD. Turned
  off by Low graphics (log 0094). Center: paper
  dust in slanting light. Upper east: nearly clean. Priestly hill: light
  shafts, incense. Underworld: ash or spores, low fog in pits.
- **Plain shapes (log 0069):** players and overworld NPCs have an
  uncoloured fill. Military armor shows as crosshatching: leather single
  diagonal, bronze cross-diagonal, iron square grid, steel triple. Cave
  gear keeps its chalk colours (contraband from below).
- **Hatching:** 2–3 crosshatch styles combined with palette colors as a
  learnable identity system (originally for dimensions; reuse for armor and
  factions).

## 9. Open questions

1. Confirm the blessed certificate rules (log 0039, proposed).
2. How often do marriages at 10+ sides produce an heir?
3. Does the 1-in-10 irregular roll apply to every heir, or only some shapes?
4. Is there a way out of the underworld for irregulars (cure quest, regular
   heir)?
4. What does renown buy, and how does it relate to lineage?
5. Can you control rotation in mid-air (aiming corners)?
6. Do classes get distinct combat, or only more corners?
7. What does each extra side give past decagon (follower count, mobility)?
8. Exact shape gate for each region and building (school, etc.).
9. Does a woman's damage scale with relative speed? What counts as "high
   velocity"?
10. Tone: how much of the book's social satire to keep.
11. Beyond the priests' puzzles (log 0076), is the slice view also the
    endgame (the Sphere's visit)?
12. Do stat caps differ by rank (sides), as Realm of the Mad God caps differ
    by class? Does rank change base stats?
13. Confirm 20 chest slots in the square's house (log 0064).
14. Momentum crits (log 0047): should a corner hit at very high speed
    (e.g. 4× the minimum hit speed) always crit, rewarding movement?
15. What lies north of the Center (log 0062), and what exactly lies west
    past the barracks (log 0061)?
16. The noble lift takes regulars only (an irregular square can't ride).
    Moot while irregulars can't leave the underworld; confirm.
17. Confirm the barracks build details (log 0077): General's shape, squad
    sizes, pay and prices, pay kept by heirs, certificate for every squad
    member, metal stats.
18. The trading booth and gathering for near-equilateral triangles (log
    0074): confirm, and what do goods sell for?
