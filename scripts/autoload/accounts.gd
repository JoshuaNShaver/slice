class_name Accounts
extends Node
## Who each client is and which family they play (design logs 0097, 0112,
## 0116). A child of Net, at /root/Net/Accounts, alike on every peer.
##
## Joining: handshake (version) -> the server says how to log in ->
## the client logs in -> the server loads that account from its store ->
## (an online account without a username picks one, log 0123) -> the
## server sends its family slots -> the client founds, deletes or picks one ->
## play. The server keeps the account's data and saves it (SaveKeeper);
## clients never send their own save.
##
## Offline and a host's own player skip the login: they're the "local"
## account, attached directly (attach_local).

## Client: the server wants a login. info: {"auth": "guest"}, or
## {"auth": "supabase", "url", "key"} (the publishable key, log 0115).
signal login_needed(info: Dictionary)
## Client: this account's slots, as Family or null, x SLOT_COUNT.
signal slots_received(families: Array)
## Client: the server refused a request but kept the connection.
signal account_error(message: String)
## Client: this account has no username yet; problem is why the last try
## was refused, or "" (log 0123).
signal username_needed(problem: String)
## Client: logged in with this username (online servers only).
signal signed_in(username: String)

const SLOT_COUNT := SaveStore.SLOT_COUNT
const LOGIN_TIMEOUT := 300.0  # s a welcomed client has to log in
const MAX_LOGIN_TRIES := 5
const GUEST_PREFIX := "guest-"
const USERNAME_MIN := 3
const USERNAME_MAX := 16
const ROLES: Array[String] = ["player", "admin", "first_architect"]  # logs 0125, 0147, 0152

## Server only.
var store: SaveStore
var keeper := SaveKeeper.new()
## How remote players log in: "guest" (a device id: LAN and dev servers)
## or "supabase" (an online server, log 0115).
var auth := "guest"
## Server only, from the environment (deploy/README.md).
var supabase_url := ""
var publishable_key := ""
var _secret_key := ""
## Server only. Finds a peer's shape (set by the world): Callable(id) -> PlayerShape.
var find_player := Callable()
## Server only. Peer id -> {"account", "username" ("" until chosen;
## always "" for guests), "role" ("player", "admin" or "first_architect";
## logs 0125, 0147, 0152),
## "families" (Family or null), "chest", "unlocks" (names, log 0174),
## "quests" (PlayerQuests.save_data, the player's across families, log 0183),
## "slot" (-1 until playing), "saved_at"}.
var sessions: Dictionary = {}
## Server only. Every login is an admin (--dev-admins, for tests and dev
## servers; log 0125).
var dev_admins := false
var _tries: Dictionary = {}

## Client only. The account's unlocks, sent with the slots (log 0174).
var unlocks: Array = []
## Client only. This player's role, as the server said (log 0147): picks
## imsdow's lines in the terminal, an admin's or a player's (log 0156).
var my_role := "player"

## Client only. Where this device keeps its guest id (tests change it).
var guest_id_path := "user://account/guest_id.txt"


## Server: picks the store (design logs 0112, 0117). A local server
## (offline, or hosting with a player) uses this machine's own files. A
## dedicated server follows SAVES: "local" (its own folder, device-id
## logins), "supabase" (needs all three SUPABASE_ settings), or unset
## (Supabase if SUPABASE_URL and SUPABASE_SECRET_KEY are set, else local).
## Returns an error message, or "".
func setup_server(dedicated: bool, save_dir := "") -> String:
	close_all()
	if store != null and store != FamilyStore.store:
		store.queue_free()
	store = null
	auth = "guest"
	dev_admins = dedicated and OS.get_cmdline_user_args().has("--dev-admins")
	supabase_url = OS.get_environment("SUPABASE_URL").strip_edges().trim_suffix("/")
	_secret_key = OS.get_environment("SUPABASE_SECRET_KEY").strip_edges()
	publishable_key = OS.get_environment("SUPABASE_PUBLISHABLE_KEY").strip_edges()
	var saves := OS.get_environment("SAVES").strip_edges().to_lower()
	if dedicated and saves == "":
		saves = "supabase" if supabase_url != "" or _secret_key != "" else "local"
	if not dedicated:
		store = FamilyStore.store
	elif saves == "supabase":
		var missing := []
		for pair: Array in [["SUPABASE_URL", supabase_url], ["SUPABASE_SECRET_KEY", _secret_key],
				["SUPABASE_PUBLISHABLE_KEY", publishable_key]]:
			if pair[1] == "":
				missing.append(pair[0])
		if not missing.is_empty():
			return "Supabase saves need %s (or set SAVES=local)." % ", ".join(missing)
		if publishable_key == _secret_key or publishable_key.begins_with("sb_secret_"):
			return "SUPABASE_PUBLISHABLE_KEY is a secret key; it would be sent to players."
		store = SupabaseStore.new(supabase_url, _secret_key)
		auth = "supabase"
	elif saves == "local":
		store = LocalFileStore.new(save_dir if save_dir != "" else "user://server/")
	else:
		return "SAVES must be local or supabase, not \"%s\"." % saves
	if store.get_parent() == null:
		store.name = "Store"
		add_child(store)
	keeper.store = store
	print("Saves: %s; logins: %s" % [store.describe(), auth])
	if dev_admins:
		print("WARNING: --dev-admins: everyone who logs in is an admin.")
	return ""


## Server: the player at this machine plays `slot` of the local account.
## False if there's no living family there.
func attach_local(id: int, slot: int) -> bool:
	var data := await store.load_account(LocalFileStore.LOCAL)
	if not data.ok:
		return false
	var session := _new_session(LocalFileStore.LOCAL, data)
	var family: Family = session.families[slot] if slot >= 0 and slot < SLOT_COUNT else null
	if family == null or family.extinct:
		return false
	session.slot = slot
	session.role = "admin"  # your own machine's game (log 0125)
	sessions[id] = session
	my_role = session.role  # only this machine's own player attaches here
	return true


func family_of(id: int) -> Family:
	var session: Dictionary = sessions.get(id, {})
	return SaveKeeper._family(session) if not session.is_empty() else null


func chest_of(id: int) -> Array:
	return sessions[id].chest if sessions.has(id) else []


## Server only. The account's quest progress (log 0183), already checked.
func quests_of(id: int) -> Dictionary:
	return sessions[id].quests if sessions.has(id) else {}


## "player", "admin" or "first_architect" (logs 0125, 0147, 0152): admins
## and the first architect (an admin like any other, log 0156) may use \
## commands in chat.
func role_of(id: int) -> String:
	if not sessions.has(id):
		return "player"
	var role: String = sessions[id].get("role", "player")
	return "admin" if dev_admins and role == "player" else role


func is_playing(id: int) -> bool:
	return family_of(id) != null


# --- Saving (server) -------------------------------------------------------

## The world calls this every few seconds for each player.
func checkpoint(p: PlayerShape, force := false) -> void:
	if sessions.has(p.peer_id):
		keeper.checkpoint(sessions[p.peer_id], p, force)


func save_all_now() -> void:
	for id: int in sessions:
		_final_save(id)


## Before a peer's shape goes: save it and forget the session.
func on_left(id: int) -> void:
	_final_save(id)
	sessions.erase(id)
	_tries.erase(id)


func close_all() -> void:
	save_all_now()
	sessions.clear()
	_tries.clear()


## Death without an heir ends the family (design log 0015); the chests stay.
## Returns the message for the player.
func on_died(id: int) -> String:
	var family := family_of(id)
	if family == null:
		return "You died."
	_final_save(id)
	family.extinct = true
	keeper.save_family(sessions[id])
	sessions[id].slot = -1
	return "The %s family has ended: died without an heir." % family.family_name


## Marriage (design log 0030): the shape is already the heir.
func on_heir(id: int, heir: Dictionary) -> void:
	var family := family_of(id)
	if family == null:
		return
	family.generation += 1
	family.sides = heir.sides
	family.kind = heir.kind
	family.apex = heir.apex
	family.luck = heir.luck
	family.progress = {}
	_unlock(id, Family.UNLOCK_IRREGULAR if heir.kind == "irregular" else "")
	var p := _shape(id)
	if p != null:
		keeper.checkpoint(sessions[id], p, true)
	keeper.save_family(sessions[id])


## Server only. The account unlocks `name` for good (log 0174); "" does nothing.
func _unlock(id: int, unlock_name: String) -> void:
	if unlock_name == "" or not sessions.has(id) or unlock_name in sessions[id].unlocks:
		return
	sessions[id].unlocks.append(unlock_name)
	store.save_unlocks(sessions[id].account, sessions[id].unlocks)


func _final_save(id: int) -> void:
	var p := _shape(id)
	if p != null and sessions.has(id):
		keeper.checkpoint(sessions[id], p, true)


func _shape(id: int) -> PlayerShape:
	return find_player.call(id) if find_player.is_valid() else null


# --- Logging in (server) ---------------------------------------------------

## What a client needs to log in here.
func login_info() -> Dictionary:
	if auth == "supabase":
		return {"auth": auth, "url": supabase_url, "key": publishable_key}
	return {"auth": auth}


## Called once a peer's version is accepted.
func offer_login(id: int) -> void:
	_login_needed.rpc_id(id, login_info())
	await get_tree().create_timer(LOGIN_TIMEOUT).timeout
	if Net.is_connected_peer(id) and not sessions.has(id):
		print("Peer %d never logged in; dropping it" % id)
		Net.kick(id)


## Client -> server: {"token": a Supabase access token} or {"guest": id}.
@rpc("any_peer", "call_remote", "reliable")
func _log_in(credential: Variant) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not Net.is_verified(id) or sessions.has(id) or _tries.get(id, 0) < 0:
		return
	_tries[id] = -1  # busy until checked
	var result := await _check(credential if credential is Dictionary else {})
	if not Net.is_connected_peer(id):
		return
	if result.has("error"):
		_refuse_login(id, result.error)
		return
	var account: String = result.account
	for other: int in sessions:
		if sessions[other].account == account:
			_take_over(other, id)
			return
	var data: Dictionary = await store.load_account(account)
	var profile := {"ok": true, "username": "", "role": "player"}
	if data.ok and auth == "supabase":
		profile = await store.load_profile(account)
	if not Net.is_connected_peer(id):
		return
	if not data.ok or not profile.ok:
		print("Couldn't load account %s for peer %d" % [account, id])
		Net.turn_away(id, "The server couldn't load your saves. Please try again later.")
		return
	sessions[id] = _new_session(account, data)
	sessions[id].username = profile.username
	var role := str(profile.get("role", "player"))
	sessions[id].role = role if role in ROLES else "player"
	print("Peer %d logged in as %s" % [id, account])
	if auth == "supabase" and profile.username == "":
		_username_needed.rpc_id(id, "")
	else:
		_welcome(id)


## The newest login wins (design log 0128): `id` takes the account over
## from `old`, which is saved and sent away. The session moves as it is in
## memory, so nothing is read back before its saves land.
func _take_over(old: int, id: int) -> void:
	_final_save(old)
	var session: Dictionary = sessions[old]
	sessions.erase(old)
	_tries.erase(old)
	session.slot = -1  # back to the family screen
	sessions[id] = session
	print("Peer %d took over %s from peer %d" % [id, session.account, old])
	Net.turn_away(old, "You signed in somewhere else.")
	if auth == "supabase" and session.username == "":
		_username_needed.rpc_id(id, "")
	else:
		_welcome(id)


## Logged in and named: the client gets its name and slots.
func _welcome(id: int) -> void:
	_role.rpc_id(id, role_of(id))
	if auth == "supabase":
		_signed_in.rpc_id(id, sessions[id].username)
	_send_slots(id)


## Why a username can't be used, or "" if it can (log 0123): 3 to 16
## letters, digits or underscores. Taken names are the store's to say.
static func username_problem(username: String) -> String:
	if username.length() < USERNAME_MIN or username.length() > USERNAME_MAX:
		return "Use %d to %d characters." % [USERNAME_MIN, USERNAME_MAX]
	for c in username:
		if not (c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9")):
			return "Use only letters, numbers and _."
	return ""


## Client -> server: the username this account wants (once).
@rpc("any_peer", "call_remote", "reliable")
func _choose_username(username: Variant) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or auth != "supabase" or not sessions.has(id):
		return
	var session: Dictionary = sessions[id]
	if session.username != "" or session.get("naming", false):
		return
	var wanted: String = username.strip_edges() if username is String else ""
	var problem := username_problem(wanted)
	if problem != "":
		_username_needed.rpc_id(id, problem)
		return
	session.naming = true
	var result := await store.claim_username(session.account, wanted)
	session.erase("naming")
	if not is_same(sessions.get(id), session):  # left meanwhile
		return
	if result.ok:
		session.username = wanted
		print("Peer %d is %s" % [id, wanted])
		_welcome(id)
	elif result.get("taken", false):
		_username_needed.rpc_id(id, "%s is taken. Try another name." % wanted)
	else:
		print("Couldn't save a username for %s: %s" % [session.account, result.get("error", "")])
		_username_needed.rpc_id(id, "The server couldn't save your name just now. Please try again.")


## {"account": String} or {"error": String}.
func _check(credential: Dictionary) -> Dictionary:
	var guest: Variant = credential.get("guest")
	if auth == "guest" and guest is String and _valid_guest(guest):
		return {"account": GUEST_PREFIX + guest}
	var token: Variant = credential.get("token")
	if auth == "supabase" and token is String and token.length() < 8192:
		return await _check_token(token)
	return {"error": "This server doesn't accept that login."}


## Supabase says whose token it is (design log 0115): one small request
## per join, and a revoked session is refused at once.
func _check_token(token: String) -> Dictionary:
	var reply := await HttpJson.request(self, HTTPClient.METHOD_GET, supabase_url + "/auth/v1/user",
			["apikey: " + _secret_key, "Authorization: Bearer " + token.strip_edges()])
	var user: Variant = reply.data
	if reply.ok and user is Dictionary and user.get("id") is String and SupabaseStore.is_uuid(user.id):
		return {"account": user.id}
	if reply.code == 401 or reply.code == 403:
		return {"error": "Your login wasn't accepted. Please log in again."}
	print("Couldn't check a login token: %s" % reply.error)
	return {"error": "The server couldn't check your login just now. Please try again."}


func _refuse_login(id: int, message: String) -> void:
	var tries: int = maxi(_tries.get(id, 0), 0) + 1
	if tries >= MAX_LOGIN_TRIES:
		Net.turn_away(id, message)
		return
	_tries[id] = tries
	_error.rpc_id(id, message)
	_login_needed.rpc_id(id, login_info())


static func _valid_guest(guest: String) -> bool:
	return guest.length() == 32 and guest.is_valid_hex_number()


func _new_session(account: String, data: Dictionary) -> Dictionary:
	var families := []
	families.resize(SLOT_COUNT)
	for i in mini(data.families.size(), SLOT_COUNT):
		var raw: Variant = data.families[i]
		families[i] = Family.from_dict(raw) if raw is Dictionary else null
	var unlocks := Family.clean_unlocks(data.get("unlocks", []), families)
	if unlocks.size() != (data.get("unlocks", []) as Array).size():
		store.save_unlocks(account, unlocks)  # keep what older saves showed
	return {"account": account, "username": "", "role": "player", "families": families, "chest": data.chest,
			"unlocks": unlocks, "quests": Quests.sanitize(data.get("quests", {})), "slot": -1,
			"saved_at": SaveKeeper._now()}


# --- Slots (server) --------------------------------------------------------

func _send_slots(id: int) -> void:
	var list := []
	for f: Family in sessions[id].families:
		list.append(f.to_dict() if f != null else null)
	_slots.rpc_id(id, list, sessions[id].unlocks)


func _session_for_menu(id: int) -> Dictionary:
	if not multiplayer.is_server() or not sessions.has(id) or sessions[id].slot >= 0:
		return {}
	if auth == "supabase" and sessions[id].username == "":
		return {}  # still picking a name
	return sessions[id]


@rpc("any_peer", "call_remote", "reliable")
func _found(slot: Variant, family_name: Variant, start_kind: Variant) -> void:
	var id := multiplayer.get_remote_sender_id()
	var session := _session_for_menu(id)
	if session.is_empty() or not (slot is int and slot >= 0 and slot < SLOT_COUNT):
		return
	if session.families[slot] != null:
		_error.rpc_id(id, "That slot is taken.")
		return
	if not Family.can_start(str(start_kind), session.unlocks):
		_error.rpc_id(id, "Irregular families are unlocked once an heir is born irregular.")
		_send_slots(id)
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var family := Family.found(str(family_name), str(start_kind), rng)
	session.families[slot] = family
	store.save_family(session.account, slot, family.to_dict())
	_send_slots(id)


@rpc("any_peer", "call_remote", "reliable")
func _delete(slot: Variant) -> void:
	var id := multiplayer.get_remote_sender_id()
	var session := _session_for_menu(id)
	if session.is_empty() or not (slot is int and slot >= 0 and slot < SLOT_COUNT):
		return
	session.families[slot] = null
	store.delete_family(session.account, slot)
	_send_slots(id)


@rpc("any_peer", "call_remote", "reliable")
func _play(slot: Variant) -> void:
	var id := multiplayer.get_remote_sender_id()
	var session := _session_for_menu(id)
	if session.is_empty() or not (slot is int and slot >= 0 and slot < SLOT_COUNT):
		return
	var family: Family = session.families[slot]
	if family == null or family.extinct:
		_error.rpc_id(id, "That family can't play.")
		return
	session.slot = slot
	_play_ok.rpc_id(id)


# --- Client ----------------------------------------------------------------

func log_in_as_guest() -> void:
	_log_in.rpc_id(1, {"guest": guest_id()})


func log_in_with_token(access_token: String) -> void:
	_log_in.rpc_id(1, {"token": access_token})


func choose_username(username: String) -> void:
	_choose_username.rpc_id(1, username.strip_edges())


func found(slot: int, family_name: String, start_kind: String) -> void:
	_found.rpc_id(1, slot, family_name, start_kind)


func delete(slot: int) -> void:
	_delete.rpc_id(1, slot)


func play(slot: int) -> void:
	_play.rpc_id(1, slot)


## This device's id for servers without accounts (LAN, dev). Made once.
func guest_id() -> String:
	var text := FileAccess.get_file_as_string(guest_id_path).strip_edges()
	if _valid_guest(text):
		return text
	text = Crypto.new().generate_random_bytes(16).hex_encode()
	DirAccess.make_dir_recursive_absolute(guest_id_path.get_base_dir())
	var file := FileAccess.open(guest_id_path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
	return text


@rpc("authority", "call_remote", "reliable")
func _login_needed(info: Dictionary) -> void:
	login_needed.emit(info)


@rpc("authority", "call_remote", "reliable")
func _username_needed(problem: String) -> void:
	username_needed.emit(problem)


@rpc("authority", "call_remote", "reliable")
func _signed_in(username: String) -> void:
	signed_in.emit(username)


@rpc("authority", "call_remote", "reliable")
func _role(role: String) -> void:
	my_role = role if role in ROLES else "player"


@rpc("authority", "call_remote", "reliable")
func _slots(list: Array, account_unlocks: Array) -> void:
	unlocks = account_unlocks
	var families := []
	families.resize(SLOT_COUNT)
	for i in mini(list.size(), SLOT_COUNT):
		families[i] = Family.from_dict(list[i]) if list[i] is Dictionary else null
	slots_received.emit(families)


@rpc("authority", "call_remote", "reliable")
func _error(message: String) -> void:
	account_error.emit(message)


@rpc("authority", "call_remote", "reliable")
func _play_ok() -> void:
	Net.on_play_accepted()
