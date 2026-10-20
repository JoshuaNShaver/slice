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
class ServerAddressExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "ServerAddress"

	func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		if not features.has("web"):
			return
		var address := OS.get_environment("SLICE_SERVER").strip_edges()
		if address == "":
			return
		# Same path as Net.BAKED_ADDRESS_FILE.
		add_file("res://server_address.txt", address.to_utf8_buffer(), false)
		print("Web build will join %s (SLICE_SERVER)" % address)
