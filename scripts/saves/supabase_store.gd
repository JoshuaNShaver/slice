class_name SupabaseStore
extends SaveStore
## Account data in Supabase Postgres, through PostgREST (design logs 0112,
## 0114): tables `families` (user_id, slot, data) and `chests` (user_id,
## items) and `profiles` (user_id, username, role; logs 0123, 0125), keyed by the
## Supabase user id. Only the server's secret key may
## touch them.
##
## Saves are queued, newest data per slot. Each slot sends one write at a
## time, so an older write can never land after a newer one. A failed
## write stays queued (unless a newer one replaced it) and is retried with
## a growing delay. Loading an account overlays writes still queued, so a
## player who rejoins quickly gets their newest data.

const LOAD_TRIES := 3
const MAX_IN_FLIGHT := 4
const RETRY_MIN := 5.0  # s, doubled per failure
const RETRY_MAX := 120.0
## A write refused this many times with a client error (bad data, the
## user deleted) is dropped, loudly; anything else is retried for ever.
const GIVE_UP_AFTER := 5

var url := ""
var _key := ""
## Key ("families:<account>:<slot>" or "chests:<account>") -> write.
## A write: {"table", "account", "slot", "data" or "items" or "delete"}.
var _pending: Dictionary = {}
var _in_flight: Dictionary = {}
var _retry_at: Dictionary = {}
var _fails: Dictionary = {}
var _tick := 0.0


func _init(supabase_url: String, secret_key: String) -> void:
	url = supabase_url.strip_edges().trim_suffix("/")
	_key = secret_key.strip_edges()


func describe() -> String:
	return "Supabase at %s" % url


func pending_count() -> int:
	return _pending.size() + _in_flight.size()


static func is_uuid(account: String) -> bool:
	var re := RegEx.create_from_string("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
	return re.search(account) != null


func load_account(account: String) -> Dictionary:
	if not is_uuid(account):
		push_error("SupabaseStore: %s isn't a user id" % account)
		return {"ok": false, "families": [], "chest": []}
	for attempt in LOAD_TRIES:
		var families := await _rest(HTTPClient.METHOD_GET,
				"families?select=slot,data&user_id=eq.%s" % account)
		var chests := await _rest(HTTPClient.METHOD_GET, "chests?select=items&user_id=eq.%s" % account)
		if families.ok and chests.ok and families.data is Array and chests.data is Array:
			return _overlay(account, _rows_to_account(families.data, chests.data))
		push_warning("Supabase: loading %s failed (%s; %s), try %d of %d" % [account,
				families.error, chests.error, attempt + 1, LOAD_TRIES])
		await get_tree().create_timer(1.0 + attempt * 2.0).timeout
	push_error("Supabase: couldn't load %s" % account)
	return {"ok": false, "families": [], "chest": []}


func load_profile(account: String) -> Dictionary:
	if not is_uuid(account):
		return {"ok": false, "username": "", "role": "player"}
	for attempt in LOAD_TRIES:
		var reply := await _rest(HTTPClient.METHOD_GET, "profiles?select=username,role&user_id=eq.%s" % account)
		if reply.ok and reply.data is Array:
			var rows: Array = reply.data
			var profile := {"ok": true, "username": "", "role": "player"}
			if not rows.is_empty() and rows[0] is Dictionary:
				profile.username = str(rows[0].get("username", ""))
				profile.role = str(rows[0].get("role", "player"))
			return profile
		push_warning("Supabase: loading the name of %s failed (%s), try %d of %d" % [account,
				reply.error, attempt + 1, LOAD_TRIES])
		await get_tree().create_timer(1.0 + attempt * 2.0).timeout
	return {"ok": false, "username": "", "role": "player"}


## One insert: the unique index on lower(username) refuses a taken name.
func claim_username(account: String, username: String) -> Dictionary:
	if not is_uuid(account):
		return {"ok": false, "error": "not a user id"}
	var reply := await _rest(HTTPClient.METHOD_POST, "profiles",
			{"user_id": account, "username": username})
	if reply.ok:
		return {"ok": true}
	if reply.code == 409:
		return {"ok": false, "taken": true}
	return {"ok": false, "error": reply.error}


func save_family(account: String, slot: int, data: Dictionary) -> void:
	_queue({"table": "families", "account": account, "slot": slot, "data": data})


func delete_family(account: String, slot: int) -> void:
	_queue({"table": "families", "account": account, "slot": slot, "delete": true})


func save_chest(account: String, items: Array) -> void:
	_queue({"table": "chests", "account": account, "items": items})


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 1.0 and not _pending.is_empty():
		_tick = 0.0
		_pump()


static func _rows_to_account(family_rows: Array, chest_rows: Array) -> Dictionary:
	var out := SaveStore.empty_account()
	for row: Variant in family_rows:
		if row is Dictionary and row.get("data") is Dictionary:
			var slot := int(row.get("slot", -1))
			if slot >= 0 and slot < SLOT_COUNT:
				out.families[slot] = row.data
	if not chest_rows.is_empty() and chest_rows[0] is Dictionary and chest_rows[0].get("items") is Array:
		out.chest = chest_rows[0].items
	return out


## Writes not yet stored are newer than the rows just read.
func _overlay(account: String, out: Dictionary) -> Dictionary:
	for queue: Dictionary in [_in_flight, _pending]:  # pending is newest
		for write: Dictionary in queue.values():
			if write.account != account:
				continue
			if write.table == "chests":
				out.chest = write.items
			else:
				out.families[write.slot] = null if write.has("delete") else write.data
	return out


static func _key_of(write: Dictionary) -> String:
	if write.table == "chests":
		return "chests:%s" % write.account
	return "families:%s:%d" % [write.account, write.slot]


func _queue(write: Dictionary) -> void:
	if not is_uuid(write.account):
		push_error("SupabaseStore: not saving for %s, not a user id" % write.account)
		return
	_pending[_key_of(write)] = write
	_pump()


func _pump() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for k: String in _pending.keys():
		if _in_flight.size() >= MAX_IN_FLIGHT:
			return
		if _in_flight.has(k) or _retry_at.get(k, 0.0) > now:
			continue
		var write: Dictionary = _pending[k]
		_pending.erase(k)
		_in_flight[k] = write
		_send(k, write)


func _send(k: String, write: Dictionary) -> void:
	var result := await _write(write)
	_in_flight.erase(k)
	if result.ok:
		_fails.erase(k)
		_retry_at.erase(k)
	else:
		var fails: int = _fails.get(k, 0) + 1
		_fails[k] = fails
		var code: int = result.code
		if code >= 400 and code < 500 and code not in [401, 403, 408, 429] and fails >= GIVE_UP_AFTER:
			push_error("Supabase: gave up saving %s after %d tries: %s" % [k, fails, result.error])
			_fails.erase(k)
		else:
			if not _pending.has(k):
				_pending[k] = write  # nothing newer came in: send this again
			var wait := minf(RETRY_MIN * pow(2.0, fails - 1), RETRY_MAX)
			_retry_at[k] = Time.get_ticks_msec() / 1000.0 + wait
			push_error("Supabase: saving %s failed (%s); retrying in %d s" % [k, result.error, wait])
	_pump()


func _write(write: Dictionary) -> Dictionary:
	var stamp := Time.get_datetime_string_from_system(true) + "Z"
	if write.table == "chests":
		return await _rest(HTTPClient.METHOD_POST, "chests?on_conflict=user_id",
				{"user_id": write.account, "items": write.items, "updated_at": stamp}, true)
	if write.has("delete"):
		return await _rest(HTTPClient.METHOD_DELETE,
				"families?user_id=eq.%s&slot=eq.%d" % [write.account, write.slot])
	return await _rest(HTTPClient.METHOD_POST, "families?on_conflict=user_id,slot",
			{"user_id": write.account, "slot": write.slot, "data": write.data, "updated_at": stamp}, true)


## A PostgREST call. Writes ask for no reply body (egress, log 0113).
func _rest(method: HTTPClient.Method, path: String, body: Variant = null, upsert := false) -> Dictionary:
	var headers := PackedStringArray(["apikey: " + _key])
	if method != HTTPClient.METHOD_GET:
		headers.append("Prefer: return=minimal" + (",resolution=merge-duplicates" if upsert else ""))
	return await HttpJson.request(self, method, "%s/rest/v1/%s" % [url, path], headers, body)
