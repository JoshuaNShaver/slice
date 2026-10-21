class_name LocalFileStore
extends SaveStore
## Account data as JSON files under one folder (design log 0112). Writes
## happen at once, through a temp file so a crash can't corrupt a save.
##
## The "local" account (the player at this machine: offline, or a LAN host
## playing) keeps today's paths: <base>families/slot_N.json and
## <base>chests.json (and <base>unlocks.json, log 0174). Any other account (a LAN guest, a dev server's
## players) lives in <base>accounts/<id>/.

const LOCAL := "local"

## Ends with "/". "user://" for the player's own saves.
var base := "user://"


func _init(base_dir := "user://") -> void:
	base = base_dir if base_dir.ends_with("/") else base_dir + "/"


func describe() -> String:
	return "local files in %s" % ProjectSettings.globalize_path(base)


static func valid_account(account: String) -> bool:
	if account == "" or account.length() > 64:
		return false
	for c in account:
		if not (c in "-_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9")):
			return false
	return true


func load_account(account: String) -> Dictionary:
	if not valid_account(account):
		push_error("LocalFileStore: bad account id %s" % account)
		return {"ok": false, "families": [], "chest": [], "unlocks": []}
	var out := SaveStore.empty_account()
	for slot in SLOT_COUNT:
		out.families[slot] = _read_family(_family_path(account, slot))
	out.chest = _read_chest(_chest_path(account))
	out.unlocks = _read_unlocks(_dir(account) + "unlocks.json")
	return out


func save_family(account: String, slot: int, data: Dictionary) -> void:
	if valid_account(account) and slot >= 0 and slot < SLOT_COUNT:
		_write(_family_path(account, slot), JSON.stringify(data, "\t"))


func delete_family(account: String, slot: int) -> void:
	if not valid_account(account):
		return
	var path := _family_path(account, slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func save_chest(account: String, items: Array) -> void:
	if valid_account(account):
		_write(_chest_path(account), JSON.stringify({"items": items}, "\t"))


func save_unlocks(account: String, names: Array) -> void:
	if valid_account(account):
		_write(_dir(account) + "unlocks.json", JSON.stringify({"names": names}, "\t"))


func _dir(account: String) -> String:
	return base if account == LOCAL else "%saccounts/%s/" % [base, account]


func _family_path(account: String, slot: int) -> String:
	return "%sfamilies/slot_%d.json" % [_dir(account), slot + 1]


func _chest_path(account: String) -> String:
	return _dir(account) + "chests.json"


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("Couldn't save %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(text)
	file.close()
	DirAccess.rename_absolute(tmp, path)


## A family's data, or null. An unreadable file is moved aside, so a new
## family can't overwrite it.
func _read_family(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and Family.from_dict(data) != null:
		return data
	DirAccess.rename_absolute(path, path + ".corrupt")
	push_warning("Unreadable family save moved to %s.corrupt" % path)
	return null


## Unreadable unlocks are just none: being born irregular again earns them.
func _read_unlocks(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data.names if data is Dictionary and data.get("names") is Array else []


func _read_chest(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and data.get("items") is Array:
		return data.items
	# Keep the unreadable file instead of letting empty chests overwrite it.
	DirAccess.rename_absolute(path, path + ".corrupt")
	push_warning("Unreadable chest save moved to %s.corrupt" % path)
	return []
