class_name Priest
extends Node2D
## The priest on the Center plaza (design log 0030). Priests are circles. Stand
## near one with a marriage certificate and press E to marry: the certificate
## is used up and you continue as your heir (Family.roll_heir).
##
## Has no body: shapes pass in front of it. The server checks the distance
## when you ask to marry.
##
## The priest also heals anyone in the Center, for free, with a pious word
## (design log 0033; PlayerShape._priest_heal).

const POSITION := Vector2(200, -46)
const RADIUS := 44.0
const REACH := 140.0  # how close you need to be to marry

## Said when the priest heals you. Circles preach regularity above all.
const BLESSINGS: Array[String] = [
	"Be whole again. Regularity is the first of the virtues.",
	"Configuration makes the man. Go, and keep your angles true.",
	"The Circle mends what the corners break. Give thanks.",
	"Rest, child. May your heir stand one side nearer perfection.",
	"Your wounds are forgiven. Irregularity never is.",
	"Every side in its place, and every place in its order. Be healed.",
]

## Set by the world each frame, for the local player.
var prompt := ""


static func random_blessing() -> String:
	return BLESSINGS.pick_random()


func _ready() -> void:
	position = POSITION
	z_index = -1  # behind the shapes


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# A circle drawn as a 40-gon, faintly halo-hatched.
	var pts := ShapeGeometry.points(40, "regular", RADIUS)
	draw_colored_polygon(pts, Palette.PARCHMENT_LIGHT)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Palette.INK, 2.5, true)
	draw_arc(Vector2.ZERO, RADIUS + 8, 0, TAU, 48, Color(Palette.CHALK[5], 0.9), 3.0, true)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-100, -RADIUS - 18), "The Priest", HORIZONTAL_ALIGNMENT_CENTER, 200, 16, Palette.INK)
	if prompt != "":
		draw_string(font, Vector2(-200, -RADIUS - 40), prompt, HORIZONTAL_ALIGNMENT_CENTER, 400, 16, Palette.INK)
