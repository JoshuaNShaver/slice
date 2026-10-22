class_name MoneyIcon
extends Control
## A currency's icon (design log 0204): "chits", a slip of army paper, or
## "coins", a verdigris coin.

var kind := "chits"


func _init(money_kind := "chits", min_size := 32.0) -> void:
	kind = money_kind
	custom_minimum_size = Vector2(min_size, min_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw(self, kind, size / 2.0, minf(size.x, size.y) * 0.42)


## Draws the icon centred on `at`, `radius` across its half-width.
static func draw(canvas: CanvasItem, money_kind: String, at: Vector2, radius: float) -> void:
	if money_kind == "coins":
		canvas.draw_circle(at, radius, Palette.COIN)
		canvas.draw_arc(at, radius, 0.0, TAU, 32, Palette.INK, 2.0, true)
		canvas.draw_arc(at, radius * 0.62, 0.0, TAU, 24, Color(Palette.PARCHMENT_LIGHT, 0.8), 1.5, true)
		return
	# A chit: a slip of paper, written on and stamped.
	var slip := Rect2(at - Vector2(radius, radius * 0.7), Vector2(radius * 2.0, radius * 1.4))
	canvas.draw_rect(slip, Palette.PARCHMENT_LIGHT)
	for k in 3:
		var y := slip.position.y + slip.size.y * (0.3 + 0.2 * k)
		canvas.draw_line(Vector2(slip.position.x + radius * 0.3, y), Vector2(slip.end.x - radius * (0.9 if k == 2 else 0.3), y),
				Palette.INK_FADED, 1.5)
	canvas.draw_circle(Vector2(slip.end.x - radius * 0.45, slip.end.y - radius * 0.4), radius * 0.22, Color(Palette.INK, 0.5))
	canvas.draw_rect(slip, Palette.INK, false, 2.0)
