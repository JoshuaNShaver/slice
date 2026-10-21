extends RefCounted
## SupabaseStore checks against tools/tests/supabase_mock.py, run by
## test_supabase_store.gd: save, load, delete, and a failed write retried
## without losing a newer one (design logs 0112, 0114).

const USER := "11111111-1111-4111-8111-111111111111"

var tree: SceneTree
var _fails := 0
var _url := ""


func run() -> int:
	_url = OS.get_environment("SUPABASE_URL")
	var store := SupabaseStore.new(_url, OS.get_environment("SUPABASE_SECRET_KEY"))
	tree.root.add_child(store)

	var bad := await store.load_account("local")
	_check(not bad.ok, "non-uuid account refused")
	var data := await store.load_account(USER)
	_check(data.ok and data.families == [null, null, null], "empty account loads")

	var family_a := {"version": 1, "family_name": "A", "sides": 3, "kind": "isosceles", "apex": 45}
	store.save_family(USER, 0, family_a)
	store.save_chest(USER, ["points_6", ""])
	store.save_unlocks(USER, [Family.UNLOCK_IRREGULAR])
	await _drain(store, 5.0)
	data = await store.load_account(USER)
	_check(data.families[0] is Dictionary and data.families[0].family_name == "A"
			and data.chest == ["points_6", ""], "saved and loaded back")
	_check(data.unlocks == [Family.UNLOCK_IRREGULAR], "unlocks saved and loaded back")

	# The next write fails; a newer one arrives while it's retrying.
	await HttpJson.request(store, HTTPClient.METHOD_POST, _url + "/_mock/fail?n=1", [])
	var family_b := family_a.duplicate()
	family_b.family_name = "B"
	var family_c := family_a.duplicate()
	family_c.family_name = "C"
	store.save_family(USER, 0, family_b)
	await tree.create_timer(0.5).timeout
	store.save_family(USER, 0, family_c)
	_check(store.pending_count() > 0, "failed write is kept for a retry")
	data = await store.load_account(USER)
	_check(data.families[0].family_name == "C", "load sees the newest unsent write")
	await _drain(store, 15.0)
	_check(store.pending_count() == 0, "retried until stored")
	var dump: Dictionary = (await HttpJson.request(store, HTTPClient.METHOD_GET, _url + "/_mock/dump", [])).data
	_check(dump.families["%s:0" % USER].data.family_name == "C", "newest write won")

	store.delete_family(USER, 0)
	await _drain(store, 5.0)
	data = await store.load_account(USER)
	_check(data.families[0] == null, "deleted")
	store.queue_free()
	print("DONE fails=%d" % _fails)
	return _fails


func _drain(store: SupabaseStore, limit: float) -> void:
	var waited := 0.0
	while store.pending_count() > 0 and waited < limit:
		await tree.create_timer(0.1).timeout
		waited += 0.1


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("%s %s" % ["ok" if ok else "FAIL", what])
