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
| West (left) | The barracks and drill yard; missions go to the front (logs 0061, 0067–0072, 0077). Past them, the coast: sailing and the Logging Isle (logs 0200–0202) | Triangles (soldiers), and any higher rank (log 0073); the coast needs a 45°+ apex |
| East, up an elevator | The Noble Quarter (log 0054) | 4+ sides, regular |
| Further east and north, up a hill | The Priests' Hill and the Temple of the Circle (log 0055) | Same as the Quarter; the sanctum is for circles (10+ sides) |
| North | Undecided (log 0062) | |
| South, down an elevator | The underworld: the Undercroft and the training cave | Regulars with 5+ sides may visit (log 0066); irregulars are confined here |

Shape gates access, and each rank keeps every activity below it (log
0073): triangles go to war; from a 45° apex they also work (woodcutting,
mining; the coast, log 0200), and from 55° trade as merchants (log 0205); squares gain the college (log 0075), circles the
dimension puzzles (log 0076). Exact gates per region are TBD (see Open
questions).
Places and spawn points live in `scripts/world/regions.gd`.

Dungeons and mazes are **procedurally generated**.

**Nothing is scenery (log 0221):** everything in the world is in the one
plane and solid; no prop stands behind the shapes. Background props
(gates, sign posts, fences, tents, crates, flags, stalls, columns) are
removed or rebuilt as solid terrain (*proposed* list in the log); place
names are handwriting in the margin. What a 3-D onlooker would see stays
as art: water drawn over a hull, armor's colour, fog, ink and paper.

**NPCs (logs 0052, 0223):** solid and immovable (elevator guards too):
they stand in your way, and you jump them or stand on them. Today every
shape can clear a square, triangle or pentagon by rolling in and jumping;
the Priest (88 px) is too tall, so he stands on a dais over the plaza. Every NPC serves some shapes and refuses others, fixed
per NPC (never a dice roll). Overworld NPCs serve regulars; most underworld
NPCs refuse them. Press interact (E) by an NPC, elevator or door to use it.

**Houses (logs 0053, 0060, 0059, 0187, 0188, 0222):** every overworld house is a regular
pentagon, as the book's law requires: roof to the north, men's large door
on the west, women's small door on the east (log 0187), no windows.
Every house is drawn open, its rooms showing (unlabelled), after the
book's plan of the narrator's house with level floors (log 0188); both
doors reach the ground. Houses are solid and big enough to go into (log
0222): walls, floors and roof are terrain, doors are gaps, and the
women's door is a slit no polygon fits. *Proposed (built):* 760 px across
(820 in the Quarter), rooms about three shapes tall, floors climbing in
~80 px steps (the Hall's treads, the middle floor, the Bedroom and the
Sons' cells). **Raised** houses stand on a floating island, the road
curving down into a valley beneath it (log 0226); islands are organic,
each its own clod of earth. The valleys are broad and gentle (about
14-15°, log 0231), with ~190 px of headroom, so a triangle rolls through,
and nobody stands in them. Getting up onto one waits on the movement
rework. **Sunken** ones stand at a road's
end under an overhang, a dead end for men (the women's side is behind).
Residents live in the rooms again. Players pass through each other (log
0225). Underworld houses break the law: crooked, lopsided, even
triangles and squares (2.6x their drawn size, log 0236).

**The Center (logs 0019, 0222):** a plaza. The land sinks west to the
barracks and rises east (a 35° slope) past Merchants' Row. Solid ledges
climb north (log 0225); *proposed (log 0062):* they stay as platforming
that later-game gear may be needed to finish. The Priest preaches from a
dais over the plaza. Over the low road west, a **raised house** on its
island (the Workman's), the road dipping into a valley under it. At the
east end, under the Noble Quarter's shelf, a **sunken house**: the
Shopkeeper in the Hall, the Strongroom Keeper in the cellar; the
Blacksmith stands at its door and the noble lift just west of it. The
old south hatch is the elevator down. A merchant stands on the Row.

**Elevators (logs 0054, 0066, 0227):** guards at both ends check your shape.
- **Down to the underworld:** regulars with 5+ sides (log 0066). Any
  regular may ride up; irregulars never can.
- **Up to the Noble Quarter:** regulars with 4+ sides.
- The ride is a plain platform, a few seconds long: a plate flush in the
  ground at each stop, no cage (log 0226). The lift down runs in an open
  shaft through the ground, capped at the top by a hatch (log 0227). Going
  down is a straight fall: the guards open the hatch and you drop to the
  Undercroft's floor. The platform only carries riders up (log 0237).
  Standing on the hatch leaves it shut (log 0249).

**The Noble Quarter (log 0063, proposed layout):** a plateau high above the
Center's east end, its cliff too tall to jump; its shelf reaches west over
the Center's sunken house (log 0222). Three raised houses over its street,
yours the middle one, the street dipping into a valley under each; a lawyer
(square) and a gentleman (hexagon) stand on the flats between, never under
a house (log 0231). **The Physician** (a pentagon) heals
regulars anywhere in the quarter. **Your house** is here (§5).

**The Priests' Hill (log 0063, proposed layout):** east of the quarter,
terraces of about 15° (decagons can stand on them) climb to the **Temple of
the Circle**. **The High Priest** marries, and heals regulars on the temple
grounds; an acolyte (12-gon) stands by. The sanctum (circles only) is sealed
for now.

**The underworld (logs 0051, 0052, 0059):** almost self-contained, since
irregulars can't leave. Its hub is **the Undercroft**, under the Center. It
is a secret (log 0171): the overworld believes irregulars are destroyed at
birth, but some are recovered here.
- **The Gleaner** (logs 0171, 0172) takes the Board's "destroyed" infants
  from the bottom of its chute, and greets irregulars waking here after
  their birth cutscene.
- Irregulars spawn here, and the home key (C) brings them here.
- **The Bonesetter** heals irregulars anywhere in the Undercroft.
- **The Hedge Priest** (a circle who failed inspection) marries irregulars.
- **The Fence** deals with anyone, regulars at a markup (no stock yet).
- Some houses have an inner floor a jump up (100 px), where a resident
  stands off the road: the Lodger, the Fence and the Squatter (log 0236).
- Its other people refuse regulars. East is sealed for now.
- Its crooked houses are big and solid, with a door at each foot: you
  roll right through them (log 0222).
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

**The barracks (logs 0061, 0067–0072, 0077, 0232):** west of the Center
(`scripts/world/barracks.gd`), all of it up on one big island (2,200 px
across, its top ~285 px over the road), no hall. Two floating steps, each
a jump up, climb from the road to its east tip; the road to the coast
runs beneath in a gentle valley, nobody standing in it. East to west on
the island:
- **The Drill Sergeant**, at the top of the steps, runs bootcamp, the
  first quest (§5c).
- **The drill yard (logs 0072, 0224, 0234):** three wild shapes (the same
  slanted rhombus with rounded corners, lying on the ground, no post;
  *proposed:* harmless, shuffling, rolling away when hit) and sparring
  partners
  (**recruits**, log 0182) for levels 1–5 (spar until about 3–5). Recruits
  can't bring you below 1 health. It drops **leather** gear.
- **The Quartermaster** (equilateral) sells bronze, iron, steel and regimental (log 0210),
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
| Recon | 5–10 | up to 4 | 3–5 rebels, 1–2 skirmishers; secretly 1 in 5 a Painted Noble (pay ×2) | 1 | secretly 1 in 10 (luck helps): a half-strength Captain (pay ×5) with a huddle (below) | 25 |
| Invasion | 10–20 | up to 8 | 20–24 rebels and agitators, 4–6 skirmishers, and 1–3 painted gentry (2× strength, use moves; log 0091) | 10 | none | 80 |
| Special ops (assassination) | 20 | up to 2 | 3 bodyguards, 2 skirmishers | none | always two: Chromatistes (gilded-buffed) and a Captain guarding him | 200 |
| Fortress raid (rangers only, §2d) | 20 | up to 4 | the enemy boat's crew, the wall-walk's guards (more if the alarm's raised), the Castellan's | a troop of 8, once the drawbridge drops | the Castellan | 250 |

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

**The west coast (logs 0200–0202, 0208; `Coast`, `Ocean`):** a little past
the barracks the ground slopes down to the sea. Only 45°+ triangles and
higher ranks go on; the Harbour Watch turns sharper ones back at the gate
("workmen only"). At the dock: the Dock Tradesman, the Boatwright, the
Harbourmaster and a pier (a floating plank: no posts, log 0221); no
house (log 0233). Then ~4,000 px of open sea, the Logging Isle
(its own pier and the Boatwright's Mate), and sea to the world's west edge.
- **Sailing (logs 0201, 0208; `Boat`):** the waves are calm at the shores
  and rough at sea, and make boats hard to sail. A boatwright launches
  your own boat (one at a time): a half-disc hull with one triangular
  sail. Rolling into the sail leans it forward and drives it; the lean
  keeps building while you hold it (about 4 s rolls it over), so you sail
  in bursts. Let go and it slows and rights itself. The use key turns it
  about, which you need to step off onto a pier. Fall in and the screen
  goes dark: you wake on the shore, everything in the bag lost (worn gear
  kept).
- **Stretches of sea (log 0215; `Ocean.STRETCHES`, numbers *proposed*):**
  each crossing brings new trouble, rougher westward. The Sound (dock to
  the Logging Isle) is the gentle one. The Narrows (Logging Isle to the
  Quarry Isle): each 128 s spell of weather has a 50% chance of rain,
  which comes on over 15 s and doubles the waves' height (log 0218). Weather follows the
  server's clock, so everyone sees the same sky. Boats ride the waves;
  they don't jump them (removed, log 0219).
- **The Logging Isle (logs 0202, 0208; `Timber`):** 6 trees in a row,
  taller than the screen. Jump or roll a corner into one, as at an enemy:
  10,000 hidden health, and every 1,000 damage drops a log (loot to pick
  up) for one hitter, picked weighted by damage dealt. Felled trees regrow
  in 3 minutes. One log per bag slot, so a full bag is 10 logs, sold to
  the Dock Tradesman for 200 chits each (log 0204).
- **The Quarry Isle (log 0211; `OreRock`, numbers *proposed*):** past more
  sea west of the Logging Isle; the Ferryman on that isle's west shore
  launches boats for it, and the Quarryman launches them home. Three ore
  rocks: 8,000 hidden health, an ore per 2,000 (4 a rock), regrowing in 5
  minutes. The Dock Tradesman pays 600 chits an ore. Trees and rocks are
  both `WorldResource`s.
- **Merchants (logs 0205, 0209; `Market`, numbers *proposed*):** a 55°+
  triangle trades between two markets.
  - The Harbourmaster sells logs from one stock shared by everyone, for
    chits (210–420) or coins (12–50); scarce is dear, a glut cheap. Logs
    workmen sell go into it, a crew adds a trickle, and gluts and
    shortages swing it every few minutes.
  - A work order (up to 10 logs at 1.5× the coin price, paid up front)
    is filled by workmen's deliveries first, the crew slowly otherwise;
    the logs wait at the dock to collect.
  - On Merchants' Row (the Center's east rise) the Market Clerk shows your
    booth's orders: up to 3, a new one every 90 s, 2–8 logs at about
    19–48 coins each, open 10 minutes. Some come in under the dock's
    price: buy cheap, hold, and wait.
  - **Promissory notes (log 0212, *proposed* numbers):** the Harbourmaster
    sells notes for coins, one per log at the dock's coin price, taken
    from the log stock. Up to 50 stack in one bag slot, and booth orders
    take them for logs (logs first, then notes). Drop a stack on another
    to merge them.
  - The Harbourmaster also sells rare ore (log 0211) from its own smaller
    stock: 620–1,260 chits or 45–150 coins, no work orders or booths.

**The Strongroom (log 0212)**: the Strongroom Keeper, in the cellar of the
Center's sunken house (log 0222), sells a family its strongroom a chest at a time: the
first for 1,000 coins, then (*proposed*) 3,000 and 8,000, 10 slots each.
Drag items between it and the bag. It belongs to the family: every heir
keeps it, and it's lost when the family ends (unlike the house chests,
which are the player's, log 0042).

**Heirlooms (log 0216):** a family with a strongroom also has five free
heirloom slots, one per gear slot. At each succession the outgoing heir's
worn armor is passed down into them; where a slot is already full, a panel
shows the old piece and the new and you click the one your heirs keep (the
other is lost). *Proposed:* the choice can wait (closed, then made at the
Strongroom); the old piece stays until then, and an unanswered choice keeps
the old piece at the next succession.

**The Blacksmith (log 0211)** stands up the Center's east hill, past
Merchants' Row, at the sunken house's door. He upgrades any piece of gear, worn or
carried, up to +5 (§4). Ore you bring him stays with him on account.

**Priests** (circles) marry you (§5): the priest on the Center plaza and the
High Priest at the temple for regulars, the Hedge Priest for irregulars.

## 2. Player and movement

- You are a regular polygon (or an irregular one, see §5).
- **Left / right:** roll. **Space:** jump. **Up / Down / Shift:** the
  abilities equipped in those slots (§2c, log 0243). **Left click:** throw
  (ranger tips, §2d; on touch, a Throw button). **E:** interact. **G:** pick up.
  **F:** drink a potion. **1–5:** quick-use slots (§4). **C:** home
  teleport (§2b). **Tab:** character
  sheet. **Esc:** menu.
- **All controls are rebindable (log 0035):** each is a named input action
  with up to two keys, changed in Esc > Controls (saved per machine).
- **Touch (log 0122):** on a touch screen, a stick under the left thumb
  rolls (analog); bottom right, a big **Jump** with the owned abilities in
  an arc around it, plus **Use** / **Take** only while something is in
  reach, close to the arc; a column up the right edge, **Drink** lowest,
  then **Chat**, **Bag**, **Menu** (log 0130); **Home** above the stick. Hints name
  these buttons. Phones play held either way (log 0134). Double
  tap an item to use it; drag a bag item onto the drop zone beside the bag
  to drop it (log 0131). Open: HUD text size on phones.
- *Proposed:* a regular n-gon holds still on slopes up to about 180°/n, so
  triangles grip steep ground and many-sided shapes slide. Terrain can gate
  shapes without doors.
- **Feel: tumbly and gymnastic (log 0020).** Holding a roll key is enough
  to tumble along, for every shape (log 0228); it builds speed over a few
  seconds, and downhill momentum can push you past it. A jump rises about
  112 px, twice a full-size shape's height (log 0228). Shapes
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
- **Multi-hit (log 0229):** every corner that strikes deals its damage, even
  several at once. More sides means more corner hits as you roll over an
  enemy. A full turn always totals 360 damage, whatever the shape. Few
  sides hit in big stomps, many sides in small hits.
- *Proposed (log 0027):* hits come from contact. A corner that strikes an
  enemy at 70+ px/s deals its damage, whether you land on the enemy or roll
  into it. Enemy corners hurt you by the same rule (flat damage per enemy
  type, minus rigidity). The same corner can't hit the same target again
  for 0.3 s, and after being hit you can't be hit again for 0.6 s.
- **Damage numbers (log 0046):** every hit's damage floats up from the
  target and fades, for all players to see. Ink for damage to enemies, red
  for damage to players.
- **Critical hits (log 0047):** each player corner hit has a 10% chance
  (raised by luck; irregulars start at 20%) to deal double damage, shown
  larger, in gold, with a "!". Enemies don't crit.
- **Speed crits (log 0229):** at critical speed (*Proposed:* 650+ px/s,
  going up not counted, and for 0.15 s after slowing) every corner hit
  crits. Rolling and jumping stay under it; rush gets there, and a long
  nose dive often does. While at it you look like a comet (log 0230): your
  leading edge glows gold under ink, and a gold tail with ink streaks
  streams out behind, longer the faster you go.
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
  then bronze, iron, steel and regimental (bought, a full set of four: 400 / 800 / 2,000 / 10,000 chits, logs 0206, 0210; leather is the main set before working). *Proposed:*
  +2 / 4 / 7 / 10 / 13, plating +3 / 6 / 10 / 15 / 19, so steel equals lilac.
  Regimental caps carry a short red ribbon on every corner. At rest they
  hang straight down and stir in the wind; moving, each trails straight
  back behind its own corner, a moment late (log 0220). No
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
  | Regimental (log 0210) | +15 vigor, +20 force |

  A military set is its four slots (points, plating, eye, voice); pigment
  doesn't count.

- **Upgrades (log 0211):** the Blacksmith raises a piece +1 to +5: 100,
  200, 300 coins, then 500 coins and 10 rare ore, then 1,000 coins and 25.
  *Proposed:* each level adds +10 / 20 / 30 / 50 / 80% of the piece's own
  bonus (regimental caps: 13, 14, 16, 17, 20, 23 force). A full set's bonus
  grows 10% per level of its lowest piece. Its halo is faint at +0 and
  brightens to +4; at +5 it becomes a gilded circle, breathing, with motes
  circling it. Icons show "+n".
- **Bag (logs 0036, 0043, 0044):** 10 slots, plus 5 **quick-use slots**
  (keys 1–5) that are bag slots too. Nothing is taken by touch. The pickup
  key (G) grabs the nearest of your items, filling the bag before the quick
  slots. **Drag and drop** moves items between any slots. **Double-click**
  an item, or press its quick-use key, to use it (wear gear, drink a
  potion, eat); on touch, double tap (log 0131). Right-click drops an
  item; on touch, drag it onto the drop zone beside the bag. Drag gear onto a character-sheet slot
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

Bought once from the Quartermaster for chits (prices, log 0206); each use costs 50 energy. An
heir starts with none. *Proposed:* keys and numbers. Each ability
is one script in `scripts/abilities/` (log 0107).

| Ability | Key | Price | What it does |
|---|---|---|---|
| Rush | Shift | 2,500 | Sideways speed and spin ×5, on the ground or in the air |
| Nose dive | Up / W | 1,000 | A jump at 1.5× jump speed (rises ~250 px, about twice a jump, clearing enemies; log 0228); coming down, your sharpest corner turns to point down and gravity pulls 2× |
| Spike up | Down / S | 5,000 | A face flat on the ground, sharpest corner up, held 1 s. Hostile enemies within 260 px are thrown up, helpless, and come down on it |

- **Equipped, not just owned (log 0243):** *proposed*, three slots, W, S
  and Shift, each holding one owned ability made for that key, swapped on
  the character sheet. Melee and ranger abilities (§2d) mix freely.

## 2d. Rangers (logs 0241–0254)

- **A ranged build, not a class (log 0241).** Ranger gear throws small
  spinning metal triangles: less damage than melee, more distance. Ranger
  school (§5c) is the account's quest, done once; it starts for a 50°+
  triangle at level 20. After it, any of the account's shapes, squares
  included, may wear ranger gear and mix it with melee gear.
- **Throwing tips (log 0242)** go in the Points slot. Left click (touch:
  Throw) throws from your shape's center, seeking the nearest hostile
  enemy, or the way you're rolling if none is in range. Each piece sets a
  shot count and spread, so later gear throws n shots in fans.
  *Proposed:* ~40% of your melee corner damage a shot, normal crits, no
  speed crits; free, 0.4 s apart; stopped by terrain and houses; never
  hurts players; gone after ~1.5 s.
- **Camouflage (log 0254):** ranger tiers have a pigment piece, and a full
  ranger set needs all five slots. It adds vigor and hides you: enemies see
  you from closer (*proposed* Scout −10% … Ranger −40%) until 3 s after you
  strike or are struck. Drawn as muted dappled patterns, one per tier.
- **Abilities (log 0244):** **volley** (W): 3× your shot count in arcs,
  farther the longer W is held, seeking the nearest enemy; **charged
  shot** (S): one straight shot at the nearest enemy that doesn't seek
  after release; holding charges damage (*proposed* up to 2×), and a glow
  flashes at the critical hold time, when a release crits; **double
  jump** (Shift slot): a second jump in mid-air (*proposed* free).
  *Proposed:* 50 energy paid on release; volley held up to 1 s, seeking
  from 0.4 s up the arc; charge full at 1.2 s, critical window 1.2–1.5 s
  (a ring closes round you, gold in the window); coins: volley 600,
  charged shot 900, double jump 400.
- **The secret island (log 0246):** the Drill Sergeant sends graduates
  (and those in training) to the rangers' island; the Ferryman brings you
  back. There: the ranger quartermaster (starting gear for chits, the rest
  for coins only), a Camp Medic, the Ranger Instructor and a yard of wild
  shapes and throwing ranger recruits. Ranger armor follows the melee stat
  curve. *Proposed:* Scout 100 chits a piece (set +10 luck); for coins,
  Tracker 150 (+10 mettle), Outrider 300 (+10 torque), Pathfinder 750 (+15
  luck), Ranger 2,000 (+15 luck, +20 force). **Rations** stack to 30 in one
  slot and heal less than salt pork (*proposed* 15% over 8 s, 2 coins).
- **Painted skirmishers (logs 0247, 0252):** Revolt rangers in all three
  missions. *Proposed:* 50° triangles that keep their distance (back off
  inside 300 px) and throw a dodgeable tip every 2–3 s from up to 600
  px, at players and soldiers alike; recon 1–2, invasion 4–6 (×1.6
  strength), special ops trades two bodyguards for them (×2.5). They
  stand at the back. Held in a huddle, they still throw. Recon's soldier
  warns of them.
- **Fortress raid (logs 0248, 0250, 0253; `Fortress`):** the rangers' own
  mission, up to 4. The General lists it for all but sends only those
  through ranger school. You land on a dock. The boatman's rowboat waits
  there and **rows across as soon as anyone speaks to it**. It holds at
  the far landing while anyone's aboard, then rows home. While it's out,
  the Boatman on the dock gives you one of your own. The crossing is a
  storm (the fortress has its own sea, `Ocean.add_sea`: steady rain,
  waves ×2.6, water only between its shores). **Keep still** aboard: a
  passenger who stays put rides it out, and rolling about can throw you
  over. **Falling in costs your bag and the mission:** the army
  fishes you out to the barracks, with no pay. **An enemy boat** is
  moored at the fortress pier, and you land just behind it. Its 3
  **archers** lob fans of 5 slow-turning homing shots and stand to charge
  a hard one. Its 2 **lookouts** run for the **back door** at the
  crags' foot once you're within 700 px. The door is hung from a tunnel's
  ceiling, rises for them and drops behind. If one gets in, **the
  alarm**: 10 archers come down the crags and 5 pentagons and 2 hexagons
  guard the winch. Kill the lookouts first and only 3 skirmishers hold
  the wall. Then you climb crags up the sea wall and cross the
  wall-walk. At the end, the **winch** on the gatehouse lets the
  drawbridge down and a troop of 8 charges in. **Carminus, the
  Castellan** (an irregular heptagon, boss) waits in his courtyard from
  the start, goes after anyone inside the fortress, and throws volleys
  and charged shots as well as his moves. His fall wins it. *Proposed:*
  level 20; rowboats ~20 s across; crags rising 120 px (a bounce each);
  wall guards ×2.5; 250 chits; the usual 1-in-5 certificate discharge.

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
  (equipment, stats); **Esc** the menu (players here, Controls, Leave). Every
  panel has an ✕ top right; the use key closes the chests, orders or shop it
  opened (log 0129). Currencies stay off the HUD, in a **Purse** tab of
  the Tab panel (log 0204): **chits**, earned by missions and work and
  spent at the barracks (kept by heirs, log 0077, proposed), and
  **coins**, the merchants' trade money, in a colour unlike any other in
  the game (*proposed:* verdigris). Top right shows the quest you're on
  (§5c). **Energy** is 2 pips over your own shape, one per
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
  potions and provisions (and the player's quests, §5c).
  - **House (logs 0041, 0054, 0064):** once a family reaches a square, it
    gets a house with chests for storage, in the Noble Quarter. Press E at
    its men's (west) door to open your chests and drag items between them and the
    bag. *Proposed:* 20 slots; everyone uses the same door, each sees their
    own chests; saved by the server with the account (log 0112). Stored gear carries over to later heirs, so
    only square-or-better runs benefit from past runs' gear; triangle runs
    start with nothing, unless their family has bought a strongroom
    (log 0212), which passes to its own heirs only. The chests belong to the player and outlive the
    family (log 0042): a new family gets them back on reaching a square.
  - **Triangles (log 0031):** only an **equilateral** triangle has a square
    heir (the book's rule). A new family's triangle is isosceles with a
    **40° apex** (log 0176); each heir's apex is **5° wider** (45°, 50°,
    55°, then 60°), so the 4th heir is equilateral.
  - **Blessed certificate (log 0032):** a rare boss drop (1 in 20). Redeemed
    by a triangle, the heir is born equilateral at once. *Proposed (log
    0039):* it drops alongside the normal certificate, skips the irregular
    roll, also cures an irregular triangle, and works as an ordinary
    certificate for anyone else (who uses ordinary ones first).
  - **Irregular roll:** 1 in 10 chance the heir is **irregular**. Irregulars
    are confined to the underworld and cannot enter the overworld. Every
    heir rolls except an equilateral's, which is always a regular square
    (log 0096).
  - **Irregular triangles (log 0096)** climb the apex too: 40°, +5° each
    heir, up to 60°, drawn with the top off to one side. The heir's apex
    widens either way; a regular roll at 60° makes it equilateral.
- **Dying without an heir ends the family.** You must create a new one.
  Since the heir takes over at once, any death ends the family.
- **New families** pick their starting triangle (logs 0050, 0065):
  **isosceles (40° apex)** or **irregular**. Equilateral is earned by
  climbing, not picked. **Irregular is hidden (logs 0174, 0175)** until
  one of the player's heirs is born irregular; the unlock is the
  account's and outlives families, like the chests.
- Past octagon you keep gaining sides. **10+ sides counts as circular: a
  priest.**
- **Past decagon, marriages don't always produce an heir** (the book's
  highest ranks struggle to have heirs). Rate TBD.

- **Cutscenes (logs 0168, 0171, 0172):** every birth (a new family, each
  heir) plays a cutscene that follows the book: the Sanitary and Social
  Board examines the newborn and a priest speaks over it, giving its
  measurements, regularity, likely occupation, and joy or dread. An
  irregular newborn is sentenced to be destroyed; the player then wakes in
  the Undercroft, greeted by the Gleaner (§1). A wedding plays one first:
  the priest marries you to a bride and congratulates you. Women are NPCs
  only (§6). Below, the Hedge Priest does both, with no Board. A cutscene
  is a full-screen overlay (the world runs on; the server keeps you safe
  until it ends), played in full the first time and skippable after. The
  officials are sincerely pompous, never cruel on purpose. A birth ends
  with a page in the book's voice, "Some years pass. You are grown." (log
  0180): you start play grown.
- **Cutscenes are data (log 0179):** a cast of actors (shape, place, size;
  a shape, a woman's line or a straw dummy) and beats whose cues act on an
  actor: move, fade, hop, jump onto another, fall, calipers, bells, a halo,
  an arc joining two, dark. Settings: the Board, the temple, the drill
  yard, below, and a page of text. Any server code (births, quests) can
  write one and run something once it ends. The format is in
  `scripts/ui/cutscene_player.gd`.

## 5c. Quests (logs 0179, 0183)

- **A quest is work critical to the plot, and it's the player's** (log
  0183): progress is kept with the account, not the family, so it outlives
  families. A new family carries on where the last left off, and a
  finished quest stays finished. A quest may be for some shapes only
  (bootcamp: regulars); with any other family it waits. Progress that
  belongs to one family (tasks, missions) is a separate thing. Quest
  characters never act as if a new family were the one they knew.
- A quest is an ordered list of steps. Each step has an objective, goals to
  check off (talk to an NPC, kill so many of an enemy, wear an item, open a
  panel, win or lose a bout), and actions when it starts or ends (a
  cutscene, a line, an item, a bout, healing). One script per quest in
  `scripts/quests/`, with its cutscenes. *Proposed (log 0182):* the HUD
  shows the current quest top right, and an NPC a quest sends you to shows
  a "!". **A word first (log 0192):** talking to someone never cuts
  straight to a cutscene; the person says something in the world, then
  the cutscene fades in over it.
- **Bootcamp (log 0181)**, the first quest, starts at a regular birth: the
  Priest sends you to the Drill Sergeant. He explains combat in a
  cutscene and shows it on a dummy (jumping surprisingly high and landing
  point first, for 9001; he wears full steel, log 0193), then: 5
  dummies, 5 recruits, leather plating (open the character sheet and wear
  it), and a bout with your senior, **Darren of the family Heroldt** (spike
  up, full leather), the start of a long friendship and rivalry. His first
  hit leaves you at 2 health. Win and he sees your potential; lose and he
  gives you pointers, glad to be working with you. Either way the Sergeant
  says you're only getting started: train until you feel ready for real
  combat, then see the General for deployment (log 0193). Darren has 1000
  health, so he's hard to beat (log 0193). *Proposed (log 0182):* only you
  fight him; his second landed hit loses the bout.
- **Ranger school (log 0245)**, the second quest, for a 50°+ triangle at
  level 20 (bootcamp done): the Drill Sergeant says you've been selected
  for a special operations unit. Blindfolded, you're taken to an entrance
  exam, an instanced platforming maze; a Heroldt descendant is waiting at
  the end. Then training like bootcamp with throwing tips: dummies,
  recruits, and a bout with the Heroldt. Win or lose, the quest ends, and
  ranger missions (§2d) and the secret island open. *Proposed (as built):*
  he's **Edric Heroldt**; the exam is ledges over water (fall in: back to
  the start) that fork twice into walled pockets, and end in a leap of
  faith off the top ledge, down past the screen, to Edric's rowboat; he
  rows you out under the east wall through the pass (log 0251); training is on the island,
  where the bout is lost on Edric's fourth hit. Home (C) leaves the exam;
  the Drill Sergeant sends you back to a fresh course (log 0249).
- **Darren's line (log 0184, not built past bootcamp):** the Heroldts are
  your rivals and friends across the game, like Red in Pokémon: always a
  step ahead. Darren is your friend in the first mission, and is later
  kidnapped by the Colour Revolt. His line rises in rank, and since your
  families may die between quests, you mostly deal with his descendants.
  They reach every secret first: they meet the Architect before you, and
  find the Third Dimension before you.

## 5b. Main menu and saves

- **Layout (logs 0185, 0186, 0187, 0188):** a torn-parchment sidebar (Offline / Online,
  Play, Quit on desktop, who's signed in, version) beside a drawn picture
  under the title banner. Play opens "Select a Family" over the picture;
  online sign-in steps show in the same panel. Buttons and panels are
  drawn by hand; lettering is IM Fell English. The picture is one street
  (no hills or anything "behind"): two big lawful houses (bigger, log 0235), your first
  family's heir between them drawn as in the game. The right house's
  family is home in its rooms (logs 0187, 0188); neighbours tumble out of the men's (west) doors and back
  in, each on his own stretch so no one passes anyone. Fog drifts behind and in front with a little
  mouse parallax (none on Low graphics).
- **Offline or Online (log 0119):** two modes, remembered. Offline is a
  local server with no network; Online joins the game's server
  (`online/server_address` in `project.godot`; on desktop
  `-- --server-address=` or `SLICE_SERVER` points elsewhere, for dev or
  LAN; a web build takes `SLICE_SERVER` at export time, log 0135). No hosting from the menu; a server runs with `-- --server`.
- **Sign-in screen (log 0120, proposed, built):** Online connects at once
  and shows one card per step: reaching the server, can't reach it (Try
  again), "Sign in with Google" (Google's white button and G), finish in
  the browser. Signed in: "Signed in as <username>" and Sign out in the
  sidebar (log 0185).
- **Usernames (log 0123):** a first online sign-in picks a username (3–16
  letters, numbers or `_`, unique ignoring case, set once) before the
  slots. The server keeps it in `profiles`; players never see an email.
- **3 family save slots.** Each slot: create a new family, play, or delete.
  Each card is a fixed height: buttons pinned to the bottom, long details
  scroll (log 0133).
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
  tables `families`, `chests`, `unlocks` (log 0174), `quests` (log 0183) and `profiles` keyed by the Supabase user, readable and
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
- **Smoothing (logs 0093, 0095, 0158, 0169, 0178):** the server sends each
  body's state 60 times a second. Clients draw other players and enemies a
  little behind (60 ms), blended between server updates; your own shape
  uses the newest update. No client-side prediction (tried and removed,
  log 0169). Between updates, a shape is carried on at the newest
  update's own velocity and spin (log 0178). When updates stop, shapes
  coast for up to 1.5 s (blending into their recent velocity and spin, slowing gently, falling under gravity, stopped by and
  sliding along terrain) instead of freezing, and when updates return the
  difference fades out (up to 0.25 s for big ones). Your own shape plays on
  instead (log 0173): after 0.12 s without an update it runs its own
  physics with your keys, and hands back to the server's updates, fading,
  once they're flowing again.
- **Clients (log 0099):** the web build is the main online client,
  installable on phones as an app (PWA, any orientation; logs 0122, 0134).
  It uses our own page (`web/shell.html`, log 0132): the phone keyboard
  covers the game instead of resizing or scrolling it, the menu lifts the
  field being typed in above the keyboard, and the page is parchment, not
  black, and re-measures after launch. Turned away
  for its version, it loads the newest build and reloads. On launch it
  also checks the host's `build_id.txt` and switches at once if that names
  another build (log 0166); otherwise a new build downloads in the
  background and is used from the next launch (log 0127, proposed).
- **Build ids (log 0166):** a build is named by its short commit, plus
  `-dirty.<hash>` for uncommitted changes. The menu shows the version with
  the build under it; `\diagnostics` shows yours and the server's.
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
- **Admins (logs 0125, 0147, 0152, 0156):** `profiles.role` is `player`,
  `admin` or `first_architect` (an admin like any other), set only by a
  database update. Admins type commands after a `\` (log 0196):
  `<noun> <verb> [words] [--flags]`, with nouns plural, each the root of
  the commands on that kind of thing. A noun alone lists them: `players`,
  `players get 3`, `players set level 11 --id 3`, `players levelup 2`;
  `help` lists them. Offline and a host's own player are admins; a
  dedicated server with `--dev-admins` makes everyone one (tests, dev).
  `enemies [--away] [--type]` and `enemies get E3` show each enemy's place,
  hp and distance from home, marking ones away from home (log 0137).
  `players quests` is a player's place in each quest: `get`, `start`,
  `set <quest> <step|done>`, `delete`, all with `--id who`; `quests` and
  `quests get <quest>` show the quests themselves (log 0196). Tab
  completes commands, verbs, fields, quests and flags (log 0163).
  `players set sides <3-64>` changes the heir's shape, keeping level and
  gear; irregulars stay irregular, a triangle made a polygon is regular
  and a polygon made a triangle equilateral (log 0213).
  `items list [search]` lists every kind of item (id and name; the search
  matches either, any case, with `*` for anything: `*steel*`), and
  `items create <item> [count] [--id who]` puts items in a bag, gear
  upgraded if named so (`points_9+3`), notes stacked (log 0214).
  `resources list [which] [--kind tree|ore] [--felled|--standing]` lists the
  trees and ore rocks (health left or when each grows back, where);
  `resources deplete <which|all> [--id who] [--bag]` fells and quarries
  them at once, their drops going to `who` (on the ground, or with `--bag`
  in the bag, the rest on the ground), and `resources regrow <which|all>`
  grows spent ones back. `which` is a name or a `*` pattern: `T*`, `O1`
  (log 0217).
- **Diagnostics (logs 0155, 0159):** anyone can type `\diagnostics` (`\diag`):
  5 pings to the server, then your fps and frame time, ping, how steadily
  your shape's updates arrive, and the server's fps, physics load, players,
  enemies, memory and uptime, the longest frame on each side (log 0160) (log 0160).
  Only you see it.
  `\diag live` keeps a short version on screen, top right, while you
  play, until you type it again. `\simulate lag 150` (optionally a
  jitter, `\simulate lag 150 30`) adds that much lag to your own
  connection, to test; `\simulate lag off` stops it (log 0159).
  `\simulate stalls 160 [every 5]` adds TCP-like stalls (nothing comes in,
  then a burst), `\simulate prod` is the live server's profile (+35 ms,
  160 ms stalls ~every 5 s), and `\simulate off` stops it all (log 0167).
- **Admin terminal (logs 0138, 0141, 0142, 0143, 0144, 0145, 0146, 0147, 0148, 0149, 0153, 0156):** a chat line starting with `\` turns the
  chat into a full-screen terminal until Esc (or ✕) closes it; in it a line
  needs no `\` (every line is a command, log 0196); Enter never
  leaves, `\hello` has imsdow wave and say hi, and `\bye` says goodbye to
  her first. Players who aren't admins can open it too; their `\help`
  lists just `\hello`, `\bye` and `\diagnostics` (logs 0153, 0155). It's 25% see-through
  dark, fixed-width font, commands echoed after an `admin@slice:~$` prompt, and an
  ASCII-art companion, **imsdow — the second architect**, who waves hello
  (click her for a new line), now and then blushes
  (pink cheeks, hearts), and is sometimes found asleep (or dozes off after
  45 s without typing): commands get mumbles until the third wakes her,
  blushing. Awake she makes shape puns, reflects, recalls design history
  with log numbers, and reacts to commands (unknown, repeated, a lost
  enemy, a player changed, an admin command from a player). Admins get the
  lines in `assets/companion/imsdow.cfg` (kind words, and facts about the
  first architect, who made the game); players who aren't admins get
  `imsdow_non_admin.cfg` (log 0156). Settings are in `imsdow.cfg`. Her animations are folders of frames in
  `assets/companion/` (text, or ink-on-clear pictures recolored
  pink/violet with a cyan shimmer; `tools/companion_ink.py` cleans a
  picture that has a background).
- **Graphics settings (log 0094):** in the in-game menu: max framerate and
  High / Low. Low drops the atmosphere, background stains and ink pass and renders at
  1280x720, scaled up. Saved per machine.
- **Window shape (logs 0126, 0134):** the game fills the window; 1280x720
  is the smallest view (720x1280 when the window is taller than wide), and
  a bigger window shows more world, never black bars. Loading screens show the title card over the Priest, his aura filling as the download's progress (log 0197).

## 8. Art direction

- **Palette:** pastel chalk colors, a fixed set. The overworld is mostly
  uncoloured (colour is banned, log 0069); colour returns a little in the
  underworld and loudly on the Colour Revolt.
- **Outlines:** dark sepia ink, so pastels stay readable on parchment.
- **Background:** parchment with ink stains in parallax layers moving at
  different speeds, giving depth as you roll left and right. Only the poor
  quarters are stained (log 0190): the Center, the Barracks, the
  Undercroft; the rest is clean parchment.
- **Menus and lettering (logs 0185, 0189):** every panel, in-game too, is
  torn parchment with pencilled buttons, fields and item slots; speech
  bubbles and the quest tracker are pencilled. All text is IM Fell English
  (the admin terminal keeps monospace).
- **A Flatlander's view (logs 0238-0240, 0249, experiment):** `\view eyes` or
  `\view eye` swaps the side view for what your shape sees: vertical bars,
  up being up, of only what's solid and the sea (no lettering or
  scenery). Ground and buildings are ink (chalk underground), people white
  or their paint (a Revolt's red), water blue; all lighten with distance
  until fog hides them at 450 px (`\view range`); beyond that, or in empty
  air, the background. Each eye sees 120° (`\view fov`). Two eyes look west
  and east; one eye turns as the mouse moves and sees the world upside
  down when facing west. `\view 2d eyes` / `2d eye` draw them over the
  side view; `\view 2d` is the default. Client only; HUD unchanged.
- **Ink on paper and fog (logs 0191, 0194, proposed):** a shader over the
  world and the menu's picture, under the UI: ink bleed and paper grain,
  and Flatland's fog as depth: the farther from your shape, the paler the
  world and the more it's crosshatched (chalk strokes underground). Off on
  Low graphics.
- **Underworld (log 0056, proposed, built):** chalk on slate. Dark ground, pale
  chalk outlines, the same pastel fills, fading in down the hatch shaft.
- **Foreground atmosphere (log 0057):** a subtle layer of dust, light or
  fog in front of the world in every region (`scripts/ui/atmosphere.gd`).
  *Proposed:* faster than the camera, client-only, under the HUD. Turned
  off by Low graphics (log 0094). Center: paper
  dust in slanting light. Upper east: nearly clean. Priestly hill: light
  shafts, incense. Underworld: ash or spores, low fog in pits. The front (logs 0195, 0198): ash rising.
- **Plain shapes (log 0069):** players and overworld NPCs have an
  uncoloured fill. Military armor shows as crosshatching: leather single
  diagonal, bronze cross-diagonal, iron square grid, steel triple. Cave
  gear keeps its chalk colours (contraband from below). NPCs can wear
  gear too: the Drill Sergeant wears full steel in the world, as in his
  cutscenes (log 0199). *Proposed:* the regimental ribbons' red is the
  regiment's colours, the one colour a soldier may wear (log 0210).
- **Nothing behind the plane (log 0221):** no props drawn for shapes to
  pass in front of. What a 3-D onlooker would see stays: water drawn over
  a hull, armor's colour and hatching, fog, ink and paper.
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
21. Is loot on the ground solid (log 0221)?
15. What lies north of the Center (log 0062)? (West past the barracks is
    the coast, log 0200.)
16. The noble lift takes regulars only (an irregular square can't ride).
    Moot while irregulars can't leave the underworld; confirm.
17. Confirm the barracks build details (log 0077): General's shape, squad
    sizes, pay and prices, pay kept by heirs, certificate for every squad
    member, metal stats.
18. Confirm the coast's and the market's built numbers (logs 0208, 0209):
    boat handling, tree regrowth, dock prices and stock, booth orders.
    Coins buy the Blacksmith's upgrades (log 0211); what else? Only
    merchants earn coins, so should soldiers and workmen have a way to
    them? (Mission pay stays low on purpose, so players work early for
    better gear, log 0207.)
20. Confirm the upgrade scaling, the +5 look and the ore numbers (logs
    0210, 0211).
19. The coins' colour (log 0204): verdigris?
