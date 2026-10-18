extends SceneTree
## Re-render: Godot --path . -s tools/render_icon.gd -- "$PWD/icon.png"
## Renders the app icon: an equilateral triangle in a full lilac set,
## drawn with the game's own Gear.draw_shape, on a parchment tile.

const SIZE := 1024
const BASE := 256.0  # drawn at this size, scaled up so line widths stay in proportion


class IconArt extends Node2D:
	func _draw() -> void:
		var c := Vector2(BASE, BASE) / 2.0
		# Rounded parchment tile with an ink border.
		var tile := Rect2(8, 8, BASE - 16, BASE - 16)
		_round_rect(tile, 40.0, Palette.PARCHMENT)
		_round_rect(tile.grow(-6), 34.0, Palette.PARCHMENT_LIGHT)
		# A few ink stains, like the menu background.
		var rng := RandomNumberGenerator.new()
		rng.seed = 1884
		for i in 9:
			var at := Vector2(rng.randf_range(40, 216), rng.randf_range(40, 216))
			for b in 3:
				draw_circle(at + Vector2(rng.randf_range(-10, 10), rng.randf_range(-8, 8)),
						rng.randf_range(4, 12), Color(Palette.INK, 0.05))
		# Soft lilac glow behind the shape.
		var lilac: Color = Gear.TIERS[3].color
		for r in range(100, 40, -6):
			draw_circle(c + Vector2(0, 6), r, Color(lilac, 0.035))
		# The triangle, full lilac set.
		var worn := PackedStringArray()
		for slot in Gear.SLOTS:
			worn.append(Gear.item(slot, 3))
		var pts := ShapeGeometry.points(3, "regular", 78.0)
		Gear.draw_shape(self, pts, 3, worn, c + Vector2(0, 14))
		# Bolder ink outline so it reads at small sizes.
		var outline := PackedVector2Array()
		for p in pts:
			outline.append(p + c + Vector2(0, 14))
		outline.append(outline[0])
		draw_polyline(outline, Palette.INK, 4.0, true)
		# Corner caps back on top of the outline.
		var s := 78.0 / 28.0
		for p in pts:
			var at := p * 0.93 + c + Vector2(0, 14)
			draw_circle(at, 3.5 * s, lilac)
			draw_arc(at, 3.5 * s, 0, TAU, 24, Palette.INK, 1.5, true)
		# Tile border.
		_round_rect_outline(tile, 40.0, Palette.INK, 5.0)

	func _round_rect(r: Rect2, rad: float, col: Color) -> void:
		draw_colored_polygon(_round_pts(r, rad), col)

	func _round_rect_outline(r: Rect2, rad: float, col: Color, w: float) -> void:
		var pts := _round_pts(r, rad)
		pts.append(pts[0])
		draw_polyline(pts, col, w, true)

	func _round_pts(r: Rect2, rad: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var corners := [r.position + Vector2(r.size.x - rad, rad), r.end - Vector2(rad, rad),
				r.position + Vector2(rad, r.size.y - rad), r.position + Vector2(rad, rad)]
		var starts := [-PI / 2, 0.0, PI / 2, PI]
		for i in 4:
			for k in 13:
				pts.append(corners[i] + Vector2.from_angle(starts[i] + k * PI / 24.0) * rad)
		return pts


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.msaa_2d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var art := IconArt.new()
	art.scale = Vector2.ONE * SIZE / BASE
	vp.add_child(art)
	root.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var out: String = OS.get_cmdline_user_args()[0]
	img.save_png(out)
	print("saved ", out)
	quit()
