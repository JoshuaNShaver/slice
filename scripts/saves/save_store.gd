class_name SaveStore
extends Node
## Where the server keeps each account's data (design logs 0097, 0112):
## up to 3 family slots (Family.to_dict(), or null) and the house chests
## (an item list, kept by the player across families, log 0042).
##
## Only the server uses a store. LocalFileStore keeps files (offline, LAN
## hosts, a dev server); SupabaseStore keeps Postgres rows (online).
## Loading may take a while, so await it. Saving returns at once: a store
## keeps the newest data for each slot and writes it when it can.

const SLOT_COUNT := 3


## {"ok": bool, "families": [Dictionary or null] x SLOT_COUNT, "chest": Array}.
## ok is false when the data couldn't be read; the caller must not play on
## (and overwrite) an account it couldn't load.
func load_account(_account: String) -> Dictionary:
	return {"ok": false, "families": [], "chest": []}


func save_family(_account: String, _slot: int, _data: Dictionary) -> void:
	pass


func delete_family(_account: String, _slot: int) -> void:
	pass


func save_chest(_account: String, _items: Array) -> void:
	pass


## Writes not yet stored (0 for a store that writes at once).
func pending_count() -> int:
	return 0


func describe() -> String:
	return "no store"


static func empty_account() -> Dictionary:
	var families := []
	families.resize(SLOT_COUNT)
	return {"ok": true, "families": families, "chest": []}
