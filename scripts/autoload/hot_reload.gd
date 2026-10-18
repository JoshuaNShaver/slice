extends Node
## Dev only: reloads edited scripts while the game or server keeps running.
## Autoloaded as HotReload.
##
## Watches every .gd file under res:// and, when one is saved, swaps the new
## code into the running script. Nodes keep their state (position, hp, ...).
## Variables you add start at their default value on existing nodes.
##
## Code in _ready() doesn't run again. A node can define _hot_reload() to
## rebuild itself after its script changes (the world rebuilds its HUD).
## Scripts with errors are skipped; the old code keeps running until fixed.
##
## On in editor builds (running from source). Turn off with --no-hot-reload.

const POLL_SECONDS := 0.5
const SKIP_DIRS: Array[String] = ["docs", "addons"]

var _mtimes: Dictionary = {}  # path -> last seen modified time
var _timer := 0.0


func _ready() -> void:
	if not OS.has_feature("editor") or OS.get_cmdline_user_args().has("--no-hot-reload"):
		set_process(false)
		return
	for path in _script_paths():
		_mtimes[path] = FileAccess.get_modified_time(path)


func _process(delta: float) -> void:
	_timer += delta
	if _timer < POLL_SECONDS:
		return
	_timer = 0.0

	var changed: Array[String] = []
	for path in _script_paths():
		var mtime := FileAccess.get_modified_time(path)
		if _mtimes.get(path, -1) != mtime:
			_mtimes[path] = mtime
			changed.append(path)
	if changed.is_empty():
		return

	var reloaded: Array[GDScript] = []
	for path in changed:
		if not ResourceLoader.has_cached(path):
			continue  # never loaded, so the new code will be used when it is
		var script: GDScript = load(path)
		if _reload(script, FileAccess.get_file_as_string(path)):
			reloaded.append(script)
			print("Hot reload: %s" % path)
		else:
			push_warning("Hot reload: %s has errors; still running the old version." % path)
	if reloaded.is_empty():
		return

	# Scripts copy other scripts' constants in when they compile, so recompile
	# the ones that name a changed class. Only those: a reload also cancels
	# any await the script is paused on.
	var names: Array[String] = []
	for script in reloaded:
		var global_name := str(script.get_global_name())
		if global_name != "":
			names.append(global_name)
		names.append_array(_autoload_names(script.resource_path))
	if not names.is_empty():
		var uses := RegEx.create_from_string("\\b(%s)\\b" % "|".join(names))
		for path in _mtimes:
			if path in changed or not ResourceLoader.has_cached(path):
				continue
			var other: GDScript = load(path)
			if uses.search(other.source_code) == null:
				continue
			if _reload(other, other.source_code):
				reloaded.append(other)
			else:
				push_warning("Hot reload: %s no longer compiles against the change." % path)

	_refresh_nodes(get_tree().root, reloaded)


## Compiles a throwaway copy first, so a typo never breaks the live script.
func _reload(script: GDScript, source: String) -> bool:
	var probe := GDScript.new()
	# A second script can't claim the same class_name. Blank that line
	# instead of removing it, so error line numbers still match the file.
	var regex := RegEx.create_from_string("(?m)^class_name\\b.*$")
	probe.source_code = regex.sub(source, "")
	if probe.reload() != OK:
		return false
	script.source_code = source
	return script.reload(true) == OK


func _refresh_nodes(node: Node, scripts: Array[GDScript]) -> void:
	var script: Variant = node.get_script()
	if script is GDScript and script in scripts:
		_fill_new_variables(node, script)
		if node is CanvasItem:
			node.queue_redraw()
		if node.has_method("_hot_reload"):
			node.call("_hot_reload")
	for child in node.get_children():
		_refresh_nodes(child, scripts)


## Variables added by the reload come up as null on nodes that already exist.
func _fill_new_variables(node: Node, script: GDScript) -> void:
	for prop in script.get_script_property_list():
		if not prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		if node.get(prop.name) == null:
			var default: Variant = script.get_property_default_value(prop.name)
			if default != null:
				node.set(prop.name, default)


## Autoloads are named in project settings, not by class_name (e.g. Net).
func _autoload_names(path: String) -> Array[String]:
	var found: Array[String] = []
	for prop in ProjectSettings.get_property_list():
		var key: String = prop.name
		if key.begins_with("autoload/") and str(ProjectSettings.get_setting(key)).trim_prefix("*") == path:
			found.append(key.trim_prefix("autoload/"))
	return found


func _script_paths(dir := "res://") -> Array[String]:
	var paths: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		var path := dir.path_join(file)
		# Not this script: it can't swap out code that's mid-call.
		if file.ends_with(".gd") and path != get_script().resource_path:
			paths.append(path)
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with(".") and sub not in SKIP_DIRS:
			paths.append_array(_script_paths(dir.path_join(sub)))
	return paths
