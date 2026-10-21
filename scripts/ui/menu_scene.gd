class_name MenuScene
extends Control
## The main menu's picture (logs 0185, 0186, 0187): a Flatland street
## drawn in ink, seen from the side as in the game, all on one line, since
## Flatland has no "behind". Two lawful pentagon houses, open to show their
## rooms as every house is (Buildings, log 0188), the ground with its pen
## hatching, and your family's heir standing between them, drawn as in the
## world (Gear). The right house's family is home (_draw_residents). The
## master, a square, comes out of the men's
## (west) door, tumbles toward your heir, waits, and goes back in to the
## Hall. The left house's man goes out of its west door, off along the
## street, and home again to his Hall; a pentagon strolls between that house and your
## heir. Each keeps to his own stretch, so no one passes anyone. Soft fog
## drifts behind the houses and along the ground in front, shifting a
## little with the mouse; Low graphics (log 0094) leaves the fog out.

## Ground line, as a share of the height.
const GROUND := 0.8
## How far each fog layer shifts as the mouse crosses the screen, in px.
const SHIFT_FAR := 21.0
const SHIFT_NEAR := 56.0
const FOG := Color(0.33, 0.3, 0.28, 0.11)
## Seconds per tumble from one face to the next (including the rest).
const STEP_TIME := 0.6
## Room kept between neighbours' stretches, in px.
const ELBOW_ROOM := 28.0
## Where the houses and your heir stand, as shares of the width.
const HOUSE_LEFT := 0.14
const HOUSE_RIGHT := 0.8
const FAMILY_AT := 0.42
const FAMILY_RADIUS := 44.0

## Your family, standing in the middle; null shows a plain new soldier.
var family: Family:
	set(value):
		family = value
		queue_redraw()

var _time := 0.0
var _look := Vector2.ZERO  # the mouse, -1 to 1 across the view, eased
var _fog: Array[Dictionary] = []
## A soft round puff, solid in the middle and fading out, for the fog.
var _puff: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 1884
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	_puff = GradientTexture2D.new()
	_puff.gradient = fade
	_puff.fill = GradientTexture2D.FILL_RADIAL
	_puff.fill_from = Vector2(0.5, 0.5)
	_puff.fill_to = Vector2(0.5, 0.0)
	_puff.width = 64
	_puff.height = 64
	for bank in 7:
		var puffs: Array[Vector3] = []
		for p in rng.randi_range(6, 11):
			puffs.append(Vector3(rng.randf_range(-90, 90), rng.randf_range(-18, 18), rng.randf_range(16, 42)))
		_fog.append({"x": rng.randf(), "near": bank >= 4, "y": rng.randf_range(-0.04, 0.05),
				"speed": rng.randf_range(5.0, 11.0), "puffs": puffs})


func _process(delta: float) -> void:
	_time += delta
	var mouse := get_viewport().get_mouse_position()
	var view := get_viewport_rect().size
	var target := ((mouse / view) * 2.0 - Vector2.ONE).clamp(-Vector2.ONE, Vector2.ONE)
	_look = _look.lerp(target, 1.0 - exp(-delta * 2.0))
	queue_redraw()


func _draw() -> void:
	var ground := size.y * GROUND
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	_draw_fog(ground, false)
	var left_width := clampf(size.x * 0.23, 190.0, 260.0)
	var right_width := clampf(size.x * 0.34, 300.0, 380.0)
	var left := Vector2(size.x * HOUSE_LEFT, ground)
	var right := Vector2(size.x * HOUSE_RIGHT, ground)
	var walkers := _walkers(left, left_width, right, right_width)
	# Houses are open (log 0188): everyone shows inside, so they're drawn
	# over the houses.
	Buildings.draw_house(self, left, left_width, Palette.PARCHMENT_LIGHT, Palette.INK)
	Buildings.draw_house(self, right, right_width, Palette.PARCHMENT_LIGHT, Palette.INK)
	_draw_ground(ground, rng)
	_draw_residents(right, right_width)
	for walker: Dictionary in walkers.values():
		_draw_walker(ground, walker)
	_draw_family(ground)
	_draw_fog(ground, true)


## A house's east and west feet: where its walls meet the ground.
static func _feet(base: Vector2, width: float) -> Vector2:
	var r := width / 1.902  # as Buildings.draw_house
	return Vector2(base.x - 0.588 * r, base.x + 0.588 * r)


## The neighbours and their stretches of street (log 0186): "home" (the
## left house's man), "master" (the open house's square) and "stroller".
## Each walks a timeline of [seconds, from step, to step]; step 0 rests
## just outside his door, positive steps lead out along `dir`, negative
## ones go in through the door.
func _walkers(left: Vector2, left_width: float, right: Vector2, right_width: float) -> Dictionary:
	var walkers := {}
	var family_left := size.x * FAMILY_AT - FAMILY_RADIUS - ELBOW_ROOM
	var family_right := size.x * FAMILY_AT + FAMILY_RADIUS + ELBOW_ROOM
	var left_feet := _feet(left, left_width)
	var right_feet := _feet(right, right_width)

	# The left house's man: out of the west door, off the edge, home again.
	var home := _walker(6, 24.0, left_feet.x - 2.0, -1, 0.0)
	var away := ceili((home.x0 + 3.0 * home.radius) / home.face)
	home.route = [[2.0, -2, -2], [1.2, -2, 0], [1.0, 0, 0], [away * STEP_TIME, 0, away], [3.0, away, away],
			[away * STEP_TIME, away, 0], [1.0, 0, 0], [1.2, 0, -2]]
	walkers.home = home

	# The open house's master: out toward your heir, then back into the
	# Hall, two steps in, short of his wife.
	var master := _walker(4, 22.0, right_feet.x - 2.0, -1, 3.5)
	var room := _steps_between(master, family_right, right_feet.x - 2.0)
	if room >= 2:
		master.route = [[4.0, -2, -2], [1.2, -2, 0], [room * STEP_TIME, 0, room], [2.5, room, room],
				[room * STEP_TIME, room, 0], [1.2, 0, -2]]
		walkers.master = master

	# A pentagon taking the air between the left house and your heir. He
	# doesn't go in: that's the east door, the women's.
	var stroller := _walker(5, 24.0, left_feet.y + ELBOW_ROOM, 1, 6.0)
	var stroll := _steps_between(stroller, left_feet.y + ELBOW_ROOM, family_left)
	if stroll >= 2:
		stroller.route = [[3.0, 0, 0], [stroll * STEP_TIME, 0, stroll], [4.0, stroll, stroll],
				[stroll * STEP_TIME, stroll, 0]]
		walkers.stroller = stroller
	return walkers


## A regular shape whose step 0 has its floor face starting at x0 and
## running along `dir` (1 right, -1 left).
static func _walker(sides: int, radius: float, x0: float, dir: int, delay: float) -> Dictionary:
	return {"sides": sides, "radius": radius, "x0": x0, "dir": dir, "delay": delay,
			"face": 2.0 * radius * sin(PI / sides), "apothem": radius * cos(PI / sides), "route": []}


## Whole steps a walker can tumble between `a` and `b`, never reaching the
## far one, even with a corner raised mid-tumble.
static func _steps_between(walker: Dictionary, a: float, b: float) -> int:
	return floori((absf(b - a) - walker.radius) / walker.face) - 1


## The right house's family, after the book's plan (log 0188), each
## standing still on his room's floor (Buildings.ROOMS), so no one meets
## anyone: his wife in the Hall, four sons in their cells, two grandsons,
## a daughter in the Wife's apartment, and three servants by the women's
## door. The master comes and goes; his Bedroom stays empty.
func _draw_residents(base: Vector2, width: float) -> void:
	var scale := width / 340.0
	var spot := func(room: String, i: int) -> Vector2:
		return Buildings.house_point(base, width, Buildings.ROOMS[room][i]) - Vector2(0, 1.5)
	_draw_woman(spot.call("hall", 0), 17.0 * scale, 0.0)
	_draw_woman(spot.call("wife", 0), 11.0 * scale, 1.7)
	for i in Buildings.ROOMS.sons.size():
		_draw_resident(spot.call("sons", i), 5, "regular", 10.0 * scale)
	for i in Buildings.ROOMS.grandsons.size():
		_draw_resident(spot.call("grandsons", i), 6, "regular", 9.0 * scale)
	for i in Buildings.ROOMS.servants.size():  # the scullion, the footman, the butler
		_draw_resident(spot.call("servants", i), 3, "isosceles", 12.0 * scale, 25)


func _draw_resident(floor_at: Vector2, sides: int, kind: String, radius: float, apex := 45) -> void:
	var pts := ShapeGeometry.points(sides, kind, radius, apex)
	var bottom := 0.0
	for p in pts:
		bottom = maxf(bottom, p.y)
	draw_set_transform(floor_at - Vector2(0, bottom))
	Gear.draw_shape(self, pts, sides, PackedStringArray())
	draw_set_transform(Vector2.ZERO)


## A woman, as in the cutscenes: a straight line with one bright eye,
## swaying gently (her peace-cry) where she stands.
func _draw_woman(foot: Vector2, radius: float, phase: float) -> void:
	var sway := sin(_time * 2.2 + phase) * 0.12
	var tip := foot + Vector2(0, -radius * 2.0).rotated(sway)
	draw_line(foot, tip, Palette.INK, 3.0, true)
	draw_circle(tip, 3.5, Palette.XP)


## Where along its route a walker is (in steps) at this moment: tumbling
## corner over corner, resting a moment on each face, as shapes roll in
## the game.
func _step_at(walker: Dictionary) -> float:
	var total := 0.0
	for leg: Array in walker.route:
		total += float(leg[0])
	var t := fposmod(_time + float(walker.delay), total)
	for leg: Array in walker.route:
		var length := float(leg[0])
		if t <= length:
			var p := lerpf(float(leg[1]), float(leg[2]), t / length)
			return floorf(p) + smoothstep(0.0, 0.75, p - floorf(p))
		t -= length
	return float(walker.route[-1][2])


## One neighbour, tipped over the corner between his faces at this step.
func _draw_walker(ground: float, walker: Dictionary) -> void:
	var sides: int = walker.sides
	var face: float = walker.face
	var step := _step_at(walker)
	var whole := floorf(step)
	var turn := (step - whole) * TAU / sides
	var pivot := Vector2(float(walker.x0) + (whole + 1.0) * face, ground - 1.5)
	var center := pivot + Vector2(-face / 2.0, -float(walker.apothem)).rotated(turn)
	var dir := float(walker.dir)  # going left: the same tumble, mirrored
	center.x = float(walker.x0) + (center.x - float(walker.x0)) * dir
	draw_set_transform(center, turn * dir)
	Gear.draw_shape(self, ShapeGeometry.points(sides, "regular", walker.radius), sides, PackedStringArray())
	draw_set_transform(Vector2.ZERO)


## The ground: shaded paper below an ink line, with the world's short pen
## strokes under the surface (CenterTerrain).
func _draw_ground(ground: float, rng: RandomNumberGenerator) -> void:
	draw_rect(Rect2(0.0, ground, size.x, size.y - ground), Color(Palette.PARCHMENT_DARK, 0.55))
	var stroke := Color(Palette.INK, 0.2)
	var x := 8.0
	while x < size.x:
		var p := Vector2(x, ground)
		draw_line(p + Vector2(4, 6), p + Vector2(-8, 18), stroke, 1.5)
		x += 16.0
	var ci := get_canvas_item()
	Sketch.line(ci, Vector2(-10.0, ground - 1.5), Vector2(size.x + 10.0, ground - 1.5), Palette.INK, 3.0, rng, 2, 0.0, 1.0)


## Your family's current heir, as the world draws it, with its name above.
func _draw_family(ground: float) -> void:
	var sides := 3
	var kind := "isosceles"
	var apex := Family.START_APEX
	var worn := PackedStringArray()
	if family != null:
		sides = family.sides
		kind = family.kind
		apex = family.apex
		worn = family.worn_gear()
	var pts := ShapeGeometry.points(sides, kind, FAMILY_RADIUS, apex)
	var bottom := 0.0
	for p in pts:
		bottom = maxf(bottom, p.y)
	var at := Vector2(size.x * FAMILY_AT, ground - 1.5 - bottom)
	draw_set_transform(at)
	Gear.draw_shape(self, pts, sides, worn)
	draw_set_transform(Vector2.ZERO)
	if family != null:
		var font := UiTheme.menu_font(true)
		draw_string(font, at + Vector2(-150, -62), "The %s family" % family.family_name,
				HORIZONTAL_ALIGNMENT_CENTER, 300, 20, Palette.INK_FADED)


## Watercolor fog: soft overlapping puffs drifting sideways. Far banks sit
## behind the houses; near ones roll along the ground in front.
func _draw_fog(ground: float, near: bool) -> void:
	if Graphics.low:
		return
	var shift := _look.x * -(SHIFT_NEAR if near else SHIFT_FAR)
	var span := size.x + 400.0
	for bank in _fog:
		if bank.near != near:
			continue
		var x := fposmod(float(bank.x) * span + _time * float(bank.speed) + shift, span) - 200.0
		var y := ground + (30.0 if near else -60.0) + float(bank.y) * size.y
		for puff: Vector3 in bank.puffs:
			var r := puff.z * 1.8
			draw_texture_rect(_puff, Rect2(x + puff.x - r, y + puff.y - r, r * 2.0, r * 2.0), false, FOG)
