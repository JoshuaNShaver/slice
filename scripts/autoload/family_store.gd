extends Node
## Local save slots for families (design log 0018). Autoloaded as FamilyStore.

signal slots_changed

const SLOT_COUNT := 3
const SAVE_DIR := "user://families"
## Your house's chests belong to you, not a family (design logs 0042, 0064).
const CHEST_PATH := "user://chests.json"

## Slot being played this session, or -1.
var active_slot := -1

## Item strings in your house's chests ("" for empty slots).
var chest: Array = []
var _slots: Array[Family] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_slots.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		_slots[i] = _load_slot(i)
	_load_chest()


func get_family(slot: int) -> Family:
	return _slots[slot]


func active_family() -> Family:
	return null if active_slot < 0 else _slots[active_slot]


func found_family(slot: int, family_name: String, start_kind: String) -> Family:
	assert(_slots[slot] == null, "slot %d is already taken" % slot)
	var f := Family.found(family_name, start_kind, _rng)
	_slots[slot] = f
	save_slot(slot)
	slots_changed.emit()
	return f


func delete_family(slot: int) -> void:
	_slots[slot] = null
	if FileAccess.file_exists(_path(slot)):
		DirAccess.remove_absolute(_path(slot))
	if active_slot == slot:
		active_slot = -1
	slots_changed.emit()


func save_slot(slot: int) -> void:
	var f := _slots[slot]
	if f == null:
		return
	# Write to a temp file first so a crash mid-write can't corrupt the save.
	var tmp := _path(slot) + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("Couldn't save family: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(f.to_dict(), "\t"))
	file.close()
	DirAccess.rename_absolute(tmp, _path(slot))


func save_chest(items: PackedStringArray) -> void:
	chest = Array(items)
	var tmp := CHEST_PATH + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("Couldn't save chests: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify({"items": chest}, "\t"))
	file.close()
	DirAccess.rename_absolute(tmp, CHEST_PATH)


func _load_chest() -> void:
	if not FileAccess.file_exists(CHEST_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHEST_PATH))
	if data is Dictionary and data.get("items") is Array:
		chest = data.items
	else:
		# Keep the unreadable file instead of letting empty chests overwrite it.
		DirAccess.rename_absolute(CHEST_PATH, CHEST_PATH + ".corrupt")
		push_warning("Unreadable chest save moved to %s.corrupt" % CHEST_PATH)


func _path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot + 1]


func _load_slot(slot: int) -> Family:
	var path := _path(slot)
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		var f := Family.from_dict(data)
		if f != null:
			return f
	# Keep the unreadable file instead of letting a new family overwrite it.
	var backup := path + ".corrupt"
	DirAccess.rename_absolute(path, backup)
	push_warning("Unreadable family save moved to %s" % backup)
	return null
