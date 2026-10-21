@tool
extends EditorPlugin
## Registers the export plugin below. See net.gd online_address().

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = ServerAddressExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


## A browser has no environment, so the web build learns SLICE_SERVER at
## export time: if it's set, the export gets res://server_address.txt.
## Unset (as on deploys), the build joins online/server_address (prod).
## Every export also gets its build id (BuildInfo, log 0166), inside it and,
## for the web, in a build_id.txt next to it that pages check on launch.
class ServerAddressExport extends EditorExportPlugin:
	var _build := ""
	var _path := ""
	var _web := false

	func _get_name() -> String:
		return "ServerAddress"

	func _export_begin(features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
		_build = BuildInfo.from_git()
		_path = path
		_web = features.has("web")
		if _build != "":
			add_file(BuildInfo.FILE, _build.to_utf8_buffer(), false)
			print("Build %s" % _build)
		if not _web:
			return
		var address := OS.get_environment("SLICE_SERVER").strip_edges()
		if address == "":
			return
		# Same path as Net.BAKED_ADDRESS_FILE.
		add_file("res://server_address.txt", address.to_utf8_buffer(), false)
		print("Web build will join %s (SLICE_SERVER)" % address)

	func _export_end() -> void:
		if not _web or _build == "" or _path == "":
			return
		var served := _path.get_base_dir().path_join(BuildInfo.SERVED)
		var file := FileAccess.open(served, FileAccess.WRITE)
		if file != null:
			file.store_string(_build + "\n")
