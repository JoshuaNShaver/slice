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
| Center | Respawn hub | Everyone |
| West (left) | War zone | Triangles (soldiers) |
| East (right) | Upper-class district | Higher ranks |
| North (up) | Priestly district | Circles / priests (10+ sides) |
| South (down) | Underworld, dungeons | Everyone; irregulars are confined here |

Shape gates access: triangles can only go to war, squares gain access to
school, and so on. Exact gates per region are TBD (see Open questions).

Dungeons and mazes are **procedurally generated**.

*Proposed (log 0019):* the **Center** is a plaza. The land sinks west,
rises east up a 35° slope, has jump-through ledges climbing north and a
sealed hatch leading south. Region exits are walls for now.

**The training cave (log 0027)** opens in the Center's west wall. Three rooms,
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

A **priest** (a circle) stands on the Center plaza and marries you (§5). While
you are in the Center he heals you in full, for free, with a pious line (§2b).

## 2. Player and movement

- You are a regular polygon (or an irregular one, see §5).
- **Left / right:** roll. **Space:** jump. **E:** interact. **G:** pick up.
  **F:** drink a potion. **1–5:** quick-use slots (§4). **C:** home
  teleport (§2b). **Tab:** character
  sheet. **Esc:** menu.
- **All controls are rebindable (log 0035):** each is a named input action
  with up to two keys, changed in Esc > Controls (saved per machine).
- *Proposed:* a regular n-gon holds still on slopes up to about 180°/n, so
  triangles grip steep ground and many-sided shapes slide. Terrain can gate
  shapes without doors.
- **Feel: tumbly and gymnastic (log 0020).** Holding a roll key builds speed
  over a few seconds, and downhill momentum can push you past it. Shapes
  are a little bouncy and keep their spin.
- **Bounce jumps:** jump again as you land. Off a face: higher than a normal
  jump. Off a corner: higher still, and you flip.
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
- *Proposed:* armor never changes your outline (it would change your corner
  angles and so your damage). Show it as fills and hatching.
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
  | Plating | armor | rigidity | a colored inner band |
  | Pigment | contraband colour (Colour Revolt) | vigor | a tint on your fill |
  | Eye | a lens for sight recognition | luck | nothing yet |
  | Voice | a pipe for your cry (an ability slot later) | mettle | nothing yet |

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

- **Bag (logs 0036, 0043, 0044):** 10 slots, plus 5 **quick-use slots**
  (keys 1–5) that are bag slots too. Nothing is taken by touch. The pickup
  key (G) grabs the nearest of your items, filling the bag before the quick
  slots. **Drag and drop** moves items between any slots. **Double-click**
  an item, or press its quick-use key, to use it (wear gear, drink a
  potion). Right-click drops an item. Drag gear onto a character-sheet slot
  to wear it, or off to remove it (double-click also removes it). Only the owner can take an item off the ground, and it
  vanishes after 90 s.
- **Stat books (log 0024):** rare consumables permanently raise one stat,
  like Realm of the Mad God's potions. *Proposed:* forbidden books such as
  treatises on color theory (color is banned after the book's Colour Revolt).

## 2b. Healing and home (logs 0033, 0034)

- **Home teleport:** C sends you to the Center at once, from anywhere, with
  no cooldown (like Realm of the Mad God's Nexus key).
- **Healing:**
  - The **priest** heals you in full, for free, while you are in the Center,
    and says something pious.
  - **Passive regen (log 0037)** everywhere: *proposed* 0.5% of max health
    per second in combat, 2% out of combat (5 s without hitting or being hit).
  - **Healing potions (log 0037)** restore *proposed* 40% of max health.
    Drink with F or by clicking one in the bag; not at full health.

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

- **Jumps cost 25 energy** (bounces too). With less you still jump, at 55%*
  speed, for free (log 0022).
- **HUD (log 0026):** top left, your shape, level, health and XP bars.
  Bottom right, the 1–5 quick-use slots over a 5×2 bag. **Tab** opens the character sheet
  (equipment, stats); **Esc** the menu (players here, Controls, Leave). Top right is
  kept for currencies. **Energy** is 4 pips over your own shape, one per
  jump, faded while full. Other players show a small health bar under their
  name.

## 5. Lineage

- **Goal of a life:** produce an heir.
- **Marriage certificates** have a chance to drop from **special events**: area
  bosses, dungeons, mazes and others. The cave's boss always drops one.
- **Redeeming a certificate** at a priest (press E nearby) produces an heir
  with **+1 side** (log 0030). The heir takes over at once and starts fresh:
  level 1, no gear. Only the family carries on, plus spare certificates
  and potions.
  - **House (log 0041):** once a family reaches a square, it gets a house
    with chests for storage. Stored gear carries over to later heirs, so
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
    are confined to the underworld and cannot enter the overworld.
- **Dying without an heir ends the family.** You must create a new one.
  Since the heir takes over at once, any death ends the family.
- **New families** pick their starting triangle (log 0050): **equilateral**,
  **isosceles (45° apex)** or **irregular**. All three are beginner classes.
- Past octagon you keep gaining sides. **10+ sides counts as circular: a
  priest.**
- **Past decagon, marriages don't always produce an heir** (the book's
  highest ranks struggle to have heirs). Rate TBD.

## 5b. Main menu and saves

- Server selection: **offline** (local server, no network), **host**, or
  **join** by address.
- **3 family save slots.** Each slot: create a new family, play, or delete.
- **Saved progress (log 0038):** a family save keeps the lineage and the
  current heir's level, XP, stats, bag and worn gear. Your machine saves
  every 3 s, on leaving and on quitting. On joining, the server caps
  anything out of range before restoring it.
- Saves are local JSON in `user://families/` for now (*proposed:* a public
  server should hold families itself).

## 6. Women (lines)

As in the book, women are straight lines.
- Bumping into one **damages you**.
- Hitting one at **high velocity kills you**.

(By the damage formula, a line's end has a 0° corner, so 180 damage.)

## 7. Multiplayer

- Online multiplayer like Realm of the Mad God / Borne Again. **Supported from
  the start, not optimized yet.**
- *Proposed architecture:* server-authoritative, using Godot's high-level
  multiplayer (ENet, `MultiplayerSpawner`, `MultiplayerSynchronizer`). Players
  send input; the server runs the simulation. Write gameplay code so a single
  player is just a local server with one peer.

## 8. Art direction

- **Palette:** pastel chalk colors, a fixed set.
- **Outlines:** dark sepia ink, so pastels stay readable on parchment.
- **Background:** parchment with ink stains in parallax layers moving at
  different speeds, giving depth as you roll left and right.
- **Hatching:** 2–3 crosshatch styles combined with palette colors as a
  learnable identity system (originally for dimensions; reuse for armor and
  factions).

## 9. Open questions

1. Confirm the blessed certificate rules (log 0039, proposed).
2. How often do marriages at 10+ sides produce an heir?
3. Does the 1-in-10 irregular roll apply to every heir, or only some shapes?
   Is there a way out of the underworld for irregulars (cure quest, regular
   heir)?
4. What does renown buy, and how does it relate to lineage?
5. Can you control rotation in mid-air (aiming corners)?
6. Do classes get distinct combat, or only more corners?
7. What does each extra side give past decagon (follower count, mobility)?
8. Exact shape gate for each region and building (school, etc.).
9. Does a woman's damage scale with relative speed? What counts as "high
   velocity"?
10. Tone: how much of the book's social satire to keep.
11. Is the original "hidden dimension / slice view" mechanic part of the game
    (e.g. as the endgame, the Sphere's visit)?
12. Do stat caps differ by rank (sides), as Realm of the Mad God caps differ
    by class? Does rank change base stats?
13. The square's house (log 0041): where is it (east district?), and how
    many chest slots?
14. Momentum crits (log 0047): should a corner hit at very high speed
    (e.g. 4× the minimum hit speed) always crit, rewarding movement?
