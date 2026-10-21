extends Node
## Starts, joins and leaves game sessions. Autoloaded as Net.
##
## Server-authoritative (design log 0013): the server owns the player list and
## sends it to clients. Offline play is a server with no network, so gameplay
## code always runs the same way.
##
## Online play runs over WebSocket for every client, desktop and web
## (design log 0110): browsers can't use ENet, and one SceneMultiplayer
## has one transport.

signal session_started
signal session_failed(reason: String)
signal session_ended(reason: String)
signal players_changed
## On the player's own machine, after marrying. `heir` is what
## Family.roll_heir made; the server has already saved it.
signal heir_born(heir: Dictionary)
## On the player's own machine: a birth or wedding cutscene to play
## (Cutscenes, design logs 0168, 0172).
signal cutscene_started(scene: Dictionary)

## Server only: how long a player watching a cutscene is kept safe at most.
const CUTSCENE_SAFE_TIME := 180.0  # s
## Server only: peer id -> what runs once their cutscene ends (play_cutscene).
var _after_cutscene: Dictionary = {}

enum Mode { OFFLINE, HOST, JOIN }

const DEFAULT_PORT := 24680
## Written into web exports when SLICE_SERVER is set (see online_address).
const BAKED_ADDRESS_FILE := "res://server_address.txt"
const MAX_CLIENTS := 32
const MAX_SIDES := 64
## WebSocket buffers per connection. The defaults (64 KiB) are too small for
## the bigger packets (a joining player's info, the world's first sync).
const BUFFER_BYTES := 1 << 20
const MAX_QUEUED_PACKETS := 4096
const QUIT_FLUSH_WAIT := 10.0  # s a quitting server waits for saves to finish
## Clients and servers must match exactly to play together (design log
## 0109). Set in project.godot (application/config/version); bump it with
## any change an older client or server couldn't play with.
var version: String = str(ProjectSettings.get_setting("application/config/version", ""))

## Peer id -> {"family", "sides", "kind", "apex", "luck", "generation"}. Set by the server.
var players: Dictionary = {}
## Server only. Peer id -> their family's saved progress (design log 0038),
## from the server's store and checked by PlayerSave.sanitize. Not sent to
## other players.
var progress: Dictionary = {}
## Server only. Peer id -> their house chests (design log 0064), checked too.
var chests: Dictionary = {}
## Server only. Peer id -> their account's quest progress (log 0183), checked.
var quests: Dictionary = {}
var mode := Mode.OFFLINE
var port := DEFAULT_PORT
var in_session := false
## A message for the main menu to show after returning to it (e.g. lost connection).
var last_message := ""
## Client: the connection, through which \simulate lag adds lag (log 0159);
## null when not joined.
var lag_peer: LagPeer

## Server only. Peer ids whose version matched; only they may log in.
var _verified: Dictionary = {}
var _handshake: Node
## Logging in, family slots and saving (design logs 0112, 0116).
var accounts: Accounts


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_handshake = preload("res://scripts/autoload/handshake.gd").new()
	_handshake.name = "Handshake"
	add_child(_handshake)
	accounts = Accounts.new()
	accounts.name = "Accounts"
	add_child(accounts)
	get_tree().auto_accept_quit = false  # a server saves first (_notification)


## Quitting: a server saves everyone, waits (a little) for an online store
## to finish writing, then quits.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	if multiplayer.is_server() and in_session:
		accounts.save_all_now()
		var waited := 0.0
		while accounts.store != null and accounts.store.pending_count() > 0 and waited < QUIT_FLUSH_WAIT:
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
	get_tree().quit()


## Plays `slot` of this machine's own families (FamilyStore).
func start_offline(slot: int) -> void:
	_reset()
	mode = Mode.OFFLINE
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_begin_as_server(slot, accounts.setup_server(false))


## Hosts and plays `slot` of this machine's families; slot -1 is a
## dedicated server with no local player, saving in `save_dir`.
func host(on_port: int, slot: int, save_dir := "") -> void:
	_reset()
	if OS.has_feature("web"):
		session_failed.emit("A browser can't host a server.")
		return
	var peer := _new_peer()
	var err := peer.create_server(on_port)
	if err != OK:
		session_failed.emit("Couldn't host on port %d (%s)." % [on_port, error_string(err)])
		return
	mode = Mode.HOST
	port = on_port
	multiplayer.multiplayer_peer = peer
	print("Server listening on port %d, version %s" % [on_port, version])
	_begin_as_server(slot, accounts.setup_server(slot < 0, save_dir))


## Connects; then Accounts asks for a login and sends the slots, and
## session_started fires once the server accepts a family to play.
## session_failed if it can't connect or is turned away. `address` is a host
## name or IP, or a full ws:// or wss:// URL (then `on_port` is ignored).
func join(address: String, on_port: int) -> void:
	_reset()
	var url := server_url(address, on_port)
	var peer := _new_peer()
	var tls := TLSOptions.client() if url.begins_with("wss://") else null
	var err := peer.create_client(url, tls)
	if err != OK:
		session_failed.emit("Couldn't connect to %s (%s)." % [url, error_string(err)])
		return
	mode = Mode.JOIN
	port = on_port
	# Through LagPeer, so \simulate lag can slow it (log 0159); no lag, no delay.
	lag_peer = LagPeer.new(peer)
	multiplayer.multiplayer_peer = lag_peer


func leave() -> void:
	lag_peer = null
	if multiplayer.is_server():
		accounts.close_all()  # saves everyone still playing
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_reset()


## The online server players join (design log 0119): the project setting
## online/server_address, unless `-- --server-address=` or SLICE_SERVER
## names another (e.g. 127.0.0.1 for a dev server). A browser has neither,
## so a web build exported with SLICE_SERVER set carries it in
## BAKED_ADDRESS_FILE (addons/server_address).
static func online_address() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--server-address="):
			return arg.trim_prefix("--server-address=").strip_edges()
	var from_env := OS.get_environment("SLICE_SERVER").strip_edges()
	if from_env != "":
		return from_env
	if FileAccess.file_exists(BAKED_ADDRESS_FILE):
		var baked := FileAccess.get_file_as_string(BAKED_ADDRESS_FILE).strip_edges()
		if baked != "":
			return baked
	return str(ProjectSettings.get_setting("online/server_address", "127.0.0.1"))


## `address`: a full ws:// or wss:// URL, a host:port, or a host (then `on_port`).
static func server_url(address: String, on_port: int) -> String:
	if address.begins_with("ws://") or address.begins_with("wss://"):
		return address
	if address.contains(":"):
		return "ws://%s" % address
	return "ws://%s:%d" % [address, on_port]


func _new_peer() -> WebSocketMultiplayerPeer:
	var peer := WebSocketMultiplayerPeer.new()
	peer.inbound_buffer_size = BUFFER_BYTES
	peer.outbound_buffer_size = BUFFER_BYTES
	peer.max_queued_packets = MAX_QUEUED_PACKETS
	return peer


func describe_session() -> String:
	match mode:
		Mode.HOST:
			return "Hosting on port %d" % port
		Mode.JOIN:
			return "Connected to server"
	return "Offline"


func _reset() -> void:
	players.clear()
	progress.clear()
	chests.clear()
	quests.clear()
	in_session = false
	_verified.clear()


func _begin_as_server(slot: int, setup_error: String) -> void:
	if setup_error != "":
		leave()
		session_failed.emit(setup_error)
		return
	if slot >= 0:
		var me := multiplayer.get_unique_id()
		if not await accounts.attach_local(me, slot):
			leave()
			session_failed.emit("That family can't play.")
			return
		_admit(me)
	in_session = true
	session_started.emit()
	players_changed.emit()


## Connected, but not in yet: the server checks the version first.
func _on_connected_to_server() -> void:
	_handshake.say_hello()


## Client. The server accepted our version; Accounts asks for a login next.
func on_welcomed() -> void:
	pass


## Client. The server accepted the family we picked: into the world.
func on_play_accepted() -> void:
	if mode != Mode.JOIN or in_session:
		return
	in_session = true
	session_started.emit()


## Client. The server turned us away (e.g. a different version).
func on_rejected(reason: String) -> void:
	if mode != Mode.JOIN:
		return
	var was_in := in_session
	leave()
	# The web build fetches the server's version and reloads (log 0122).
	var theirs := WebApp.version_in_rejection(reason)
	if theirs != "" and WebApp.update_to(theirs):
		reason = "This server runs version %s. Loading it…" % theirs
	if was_in:
		session_ended.emit(reason)
	else:
		session_failed.emit(reason)


## Server only.
func verify(id: int) -> void:
	_verified[id] = true
	accounts.offer_login.call_deferred(id)  # after the welcome


## Server only. Tells a client why, then closes its connection.
func turn_away(id: int, reason: String) -> void:
	_handshake.turn_away(id, reason)


func is_verified(id: int) -> bool:
	return _verified.has(id)


func is_connected_peer(id: int) -> bool:
	return id in multiplayer.get_peers()


## Server only. Closes a client's connection.
func kick(id: int) -> void:
	if multiplayer.multiplayer_peer != null and is_connected_peer(id):
		multiplayer.multiplayer_peer.disconnect_peer(id)


## The world calls this once it has loaded. A joining client registers only
## then, so the server never spawns shapes for a client with no world yet.
func announce_ready() -> void:
	if mode == Mode.JOIN and in_session:
		_register.rpc_id(1, {})


func _on_connection_failed() -> void:
	leave()
	session_failed.emit("Couldn't reach the server.")


func _on_server_disconnected() -> void:
	var was_in := in_session
	leave()
	if was_in:
		session_ended.emit("Lost connection to the server.")
	else:
		session_failed.emit("The server closed the connection.")


func _on_peer_connected(id: int) -> void:
	if mode != Mode.HOST:
		return
	var peer := multiplayer.multiplayer_peer as WebSocketMultiplayerPeer
	if peer != null:
		print("Peer %d connecting from %s:%d" % [id, peer.get_peer_address(id), peer.get_peer_port(id)])
	if multiplayer.get_peers().size() > MAX_CLIENTS:
		print("Server full; turning away peer %d" % id)
		_handshake.turn_away(id, "The server is full. Try again later.")
		return
	_handshake.expect_hello(id)


func _on_peer_disconnected(id: int) -> void:
	accounts.on_left(id)  # while its shape is still there
	_verified.erase(id)
	progress.erase(id)
	chests.erase(id)
	quests.erase(id)
	if multiplayer.is_server() and players.erase(id):
		print("Peer %d left" % id)
		_broadcast_players()


## Client -> server: "my world is ready". Anything a client sends here is
## ignored: the server plays the family it picked (Accounts).
@rpc("any_peer", "call_remote", "reliable")
func _register(_info: Variant) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not is_verified(id) or not accounts.is_playing(id):
		kick(id)
		return
	if players.has(id):
		return
	_admit(id)
	print("Peer %d joined as the %s family" % [id, players[id].family])
	_broadcast_players()


## Server only. Puts the family a peer picked into the session. The save
## is the server's own, but is still checked (defence in depth).
func _admit(id: int) -> void:
	var family := accounts.family_of(id)
	players[id] = _sanitize(family.to_public_info())
	progress[id] = PlayerSave.sanitize(family.progress)
	family.progress = progress[id]
	chests[id] = PlayerSave.clean_items(accounts.chest_of(id), PlayerInventory.CHEST_SLOTS)
	quests[id] = Quests.sanitize(accounts.quests_of(id))


## Server -> clients: the full player list.
@rpc("authority", "call_remote", "reliable")
func _receive_players(list: Dictionary) -> void:
	players = list
	players_changed.emit()


func _broadcast_players() -> void:
	if not multiplayer.get_peers().is_empty():
		_receive_players.rpc(players)
	players_changed.emit()


## Server only. A player's health hit 0: the family ends (saved by
## Accounts), the player is told, then dropped from the session.
func player_died(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	print("Peer %d died" % id)
	var reason := accounts.on_died(id)
	progress.erase(id)
	chests.erase(id)
	quests.erase(id)
	_you_died.rpc_id(id, reason)
	if players.erase(id):
		_broadcast_players()


## Server only. Marriage (design log 0030): save the heir, tell the player.
func heir_born_on_server(id: int, heir: Dictionary) -> void:
	accounts.on_heir(id, heir)
	if players.has(id):
		players[id].sides = heir.sides
		players[id].kind = heir.kind
		players[id].apex = heir.apex
		players[id].luck = heir.luck
		players[id].generation += 1
		_broadcast_players()
	_heir_born.rpc_id(id, heir)


## Server only. Plays a cutscene (CutscenePlayer's format) on one player's
## screen. They can't be hurt until it ends (cutscene_done) or for
## CUTSCENE_SAFE_TIME. `then` runs on the server once it has ended (watched
## or skipped), e.g. a quest's next step (log 0179); not if they leave first.
func play_cutscene(id: int, scene: Dictionary, then := Callable()) -> void:
	var shape := _shape_of(id)
	if shape != null:
		shape.combat.keep_safe(CUTSCENE_SAFE_TIME)
	var waiting: Array = _after_cutscene.get(id, [])
	if then.is_valid():
		waiting.append(then)
	_after_cutscene[id] = waiting
	_cutscene.rpc_id(id, scene)


@rpc("authority", "call_local", "reliable")
func _cutscene(scene: Dictionary) -> void:
	cutscene_started.emit(scene)


## Owner side: the cutscene is over (watched or skipped).
func cutscene_done() -> void:
	if multiplayer.has_multiplayer_peer():
		_cutscene_done.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _cutscene_done() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = multiplayer.get_unique_id()
	var shape := _shape_of(id)
	if shape != null:
		shape.combat.keep_safe(0.0)
	# It ended: run what waited for it (and for any it replaced on screen).
	var waiting: Array = _after_cutscene.get(id, [])
	_after_cutscene.erase(id)
	for then: Callable in waiting:
		if then.is_valid() and shape != null:
			then.call()


## Server only. The world's shape for a player (the world sets
## accounts.find_player), or null.
func _shape_of(id: int) -> PlayerShape:
	return accounts.find_player.call(id) if accounts.find_player.is_valid() else null


## Server -> the player who died. Dying without an heir ends the family
## (design log 0015).
@rpc("authority", "call_local", "reliable")
func _you_died(reason: String) -> void:
	leave()
	session_ended.emit(reason)


## Server -> the player who married.
@rpc("authority", "call_local", "reliable")
func _heir_born(heir: Dictionary) -> void:
	heir_born.emit(heir)


## Never trust what a client sends.
func _sanitize(info: Dictionary) -> Dictionary:
	var raw_sides: Variant = info.get("sides", 3)
	var raw_kind: Variant = info.get("kind", "regular")
	var raw_luck: Variant = info.get("luck", 0)
	var raw_apex: Variant = info.get("apex", 0)
	var raw_generation: Variant = info.get("generation", 1)
	var clean := {
		"family": Family.clean_name(str(info.get("family", ""))),
		"sides": clampi(raw_sides if raw_sides is int else 3, 3, MAX_SIDES),
		"kind": raw_kind if raw_kind is String and raw_kind in Family.KINDS else "regular",
		"apex": 0,
		"luck": clampi(raw_luck if raw_luck is int else 0, 0, Stats.MAX_LUCK),
		"generation": maxi(raw_generation if raw_generation is int else 1, 1),
	}
	if clean.kind == "isosceles" and clean.sides != 3:
		clean.kind = "regular"
	clean.apex = Family.clean_apex(clean.sides, clean.kind,
			raw_apex if raw_apex is int else Family.START_APEX)
	return clean
