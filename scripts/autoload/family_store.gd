extends Node
## The 3 family slots of the player at this machine (design log 0018), for
## the main menu's offline and host modes. Autoloaded as FamilyStore.
##
## The files are a LocalFileStore's "local" account (design log 0112). A
## local server (offline, or hosting) loads and saves the same account
## through `store`; this node only lists, founds and deletes before play.
## Online, the slots live on the server instead (Accounts).

signal slots_changed

const SLOT_COUNT := SaveStore.SLOT_COUNT

var store: LocalFileStore
var _slots: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	use_base("user://")


## Tests point this at a temporary folder so real saves aren't touched.
func use_base(base_dir: String) -> void:
	if store != null:
		store.queue_free()
	store = LocalFileStore.new(base_dir)
	store.name = "LocalFiles"
	add_child(store)
	reload()


## Reads the slots again (after playing, a local server has saved them).
func reload() -> void:
	var data := store.load_account(LocalFileStore.LOCAL)
	_slots.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		var raw: Variant = data.families[i] if data.ok else null
		_slots[i] = Family.from_dict(raw) if raw is Dictionary else null
	slots_changed.emit()


func get_family(slot: int) -> Family:
	return _slots[slot]


func found_family(slot: int, family_name: String, start_kind: String) -> Family:
	assert(_slots[slot] == null, "slot %d is already taken" % slot)
	var f := Family.found(family_name, start_kind, _rng)
	_slots[slot] = f
	store.save_family(LocalFileStore.LOCAL, slot, f.to_dict())
	slots_changed.emit()
	return f


func delete_family(slot: int) -> void:
	_slots[slot] = null
	store.delete_family(LocalFileStore.LOCAL, slot)
	slots_changed.emit()
