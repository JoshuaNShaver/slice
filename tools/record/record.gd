extends SceneTree
## Plays one scripted clip of the real game, for the README's GIFs. Run it
## through tools/record/make_gifs.sh, which records it with Godot's movie
## mode and turns it into a GIF.
##
##   Godot --path . --resolution 1280x720 --write-movie out.avi -s tools/record/record.gd -- --no-hot-reload --clip=invasion
##
## Clips (clips.gd): invasion (a battle at the front), lift (the ride down
## to the Undercroft). The world runs offline with made-up players and no
## account, so nothing is saved. Prints "TRIM <frames>" where the clip
## starts, for the GIF maker to cut what's before.

var _clips: RefCounted


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if _clips != null:
		_clips.frame += 1
	return false


func _run() -> void:
	await process_frame
	_clips = load("res://tools/record/clips.gd").new()
	_clips.tree = self
	await _clips.run()
	quit()
