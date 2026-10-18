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

## 2. Player and movement

- You are a regular polygon (or an irregular one, see §5).
- **Left / right:** roll. **Space:** jump.
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
  other. In mid-air you drift sideways but don't turn (see Open question 7).

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
- High ranks can bring triangles to fight for them.
- All classes may use the same combat, or classes may get distinct combat.
  Undecided.

## 4. Gear and leveling

- All classes equip **armor**. Collected **trinkets** stack, Risk of Rain style.
- *Proposed:* armor never changes your outline (it would change your corner
  angles and so your damage). Show it as fills and hatching.
- **Leveling:** max level 20, reached in about 30 minutes. After that you earn
  **renown**, the meta currency.
- **Stat books (log 0024):** rare consumables permanently raise one stat,
  like Realm of the Mad God's potions. *Proposed:* forbidden books such as
  treatises on color theory (color is banned after the book's Colour Revolt).

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
| Luck | Good-outcome chances × (1 + luck/50), so 50 doubles them. Rolled at birth (0–10*), irregulars ×2, never levels | 0–10 (irregular 0–20) |

- **Jumps cost 25 energy** (bounces too). With less you still jump, at 55%*
  speed, for free (log 0022).
- **HUD (log 0025):** your health and energy bars sit bottom right, a
  quarter of the screen wide, on top of a 3-tab menu: **Bag**, **Equipment**
  and **Stats**. Bag and Equipment are empty placeholders for now. Other
  players show a small health bar under their name.

## 5. Lineage

- **Goal of a life:** produce an heir.
- **Marriage certificates** have a chance to drop from **special events**: area
  bosses, dungeons, mazes and others.
- **Redeeming a certificate** produces an heir with **+1 side**.
  - **Triangles:** only an **equilateral** triangle is guaranteed a square
    heir (the book's rule). Other triangles get no guarantee.
  - **Irregular roll:** 1 in 10 chance the heir is **irregular**. Irregulars
    are confined to the underworld and cannot enter the overworld.
- **Dying without an heir ends the family.** You must create a new one.
- **New families** start as a rolled triangle:

  | Triangle | Chance |
  |---|---|
  | Equilateral | 0% |
  | Right | 40% |
  | Acute | 40% |
  | Irregular | 10% |

  These add up to 90%; the last 10% is unassigned (see Open questions). The
  code rescales the weights until then.
- Past octagon you keep gaining sides. **10+ sides counts as circular: a
  priest.**
- **Past decagon, marriages don't always produce an heir** (the book's
  highest ranks struggle to have heirs). Rate TBD.

## 5b. Main menu and saves

- Server selection: **offline** (local server, no network), **host**, or
  **join** by address.
- **3 family save slots.** Each slot: create a new family, play, or delete.
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

1. The starting-triangle roll adds up to 90%. What is the last 10% (obtuse?)?
   And what exact angles do right and acute triangles have (fixed 45-45-90,
   or rolled)?
2. How do right and acute triangles reach equilateral, if they can (e.g. the
   apex widens toward 60° each generation, as in the book)?
3. How often do marriages at 10+ sides produce an heir?
4. Does the 1-in-10 irregular roll apply to every heir, or only some shapes?
   Is there a way out of the underworld for irregulars (cure quest, regular
   heir)?
5. What carries from a parent to an heir: level, gear, trinkets?
6. What does renown buy, and how does it relate to lineage?
7. Can you control rotation in mid-air (aiming corners)?
8. Do classes get distinct combat, or only more corners?
9. What does each extra side give past decagon (follower count, mobility)?
10. Exact shape gate for each region and building (school, etc.).
11. Does a woman's damage scale with relative speed? What counts as "high
    velocity"?
12. Tone: how much of the book's social satire to keep.
13. Is the original "hidden dimension / slice view" mechanic part of the game
    (e.g. as the endgame, the Sphere's visit)?
14. Do stat caps differ by rank (sides), as Realm of the Mad God caps differ
    by class? Does rank change base stats?
