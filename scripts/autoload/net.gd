extends Node
## Starts, joins and leaves game sessions. Autoloaded as Net.
##
## Server-authoritative (design log 0013): the server owns the player list and
## sends it to clients. Offline play is a server with no network, so gameplay
## code always runs the same way.

signal session_started
signal session_failed(reason: String)
signal session_ended(reason: String)
signal players_changed
## On the player's own machine, after their family save is updated.
## `heir` is what Family.roll_heir made.
signal heir_born(heir: Dictionary)

enum Mode { OFFLINE, HOST, JOIN }

const DEFAULT_PORT := 24680
const MAX_CLIENTS := 32
const MAX_SIDES := 64

## Peer id -> {"family", "sides", "kind", "apex", "luck", "generation"}. Set by the server.
var players: Dictionary = {}
## Server only. Peer id -> the saved progress they joined with (design log
## 0038), checked by PlayerShape.sanitize_progress. Not sent to other players.
var progress: Dictionary = {}
var mode := Mode.OFFLINE
var port := DEFAULT_PORT
var in_session := false
## A message for the main menu to show after returning to it (e.g. lost connection).
var last_message := ""

var _local_info: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func start_offline(info: Dictionary) -> void:
	_reset()
	mode = Mode.OFFLINE
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_begin_as_server(info)


## Pass an empty info for a dedicated server with no local player.
func host(on_port: int, info: Dictionary) -> void:
	_reset()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(on_port, MAX_CLIENTS)
	if err != OK:
		session_failed.emit("Couldn't host on port %d (%s)." % [on_port, error_string(err)])
		return
	mode = Mode.HOST
	port = on_port
	multiplayer.multiplayer_peer = peer
	print("Server listening on port %d" % on_port)
	_begin_as_server(info)


## session_started fires once connected, session_failed if it can't connect.
func join(address: String, on_port: int, info: Dictionary) -> void:
	_reset()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, on_port)
	if err != OK:
		session_failed.emit("Couldn't connect to %s:%d (%s)." % [address, on_port, error_string(err)])
		return
	mode = Mode.JOIN
	port = on_port
	_local_info = info
	multiplayer.multiplayer_peer = peer


func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_reset()


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
	in_session = false
	_local_info = {}


func _begin_as_server(info: Dictionary) -> void:
	in_session = true
	if not info.is_empty():
		_admit(multiplayer.get_unique_id(), info)
	session_started.emit()
	players_changed.emit()


func _on_connected_to_server() -> void:
	in_session = true
	session_started.emit()


## The world calls this once it has loaded. A joining client registers only
## then, so the server never spawns shapes for a client with no world yet.
func announce_ready() -> void:
	if mode == Mode.JOIN and in_session:
		_register.rpc_id(1, _local_info)


func _on_connection_failed() -> void:
	leave()
	session_failed.emit("Couldn't reach the server.")


func _on_server_disconnected() -> void:
	leave()
	session_ended.emit("Lost connection to the server.")


func _on_peer_disconnected(id: int) -> void:
	progress.erase(id)
	if multiplayer.is_server() and players.erase(id):
		print("Peer %d left" % id)
		_broadcast_players()


## Client -> server: "this is who I am".
@rpc("any_peer", "call_remote", "reliable")
func _register(info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	_admit(id, info)
	print("Peer %d joined as the %s family" % [id, players[id].family])
	_broadcast_players()


## Server only. Never trust what a client sends.
func _admit(id: int, info: Dictionary) -> void:
	players[id] = _sanitize(info)
	var raw: Variant = info.get("progress", {})
	progress[id] = PlayerShape.sanitize_progress(raw if raw is Dictionary else {})


## Server -> clients: the full player list.
@rpc("authority", "call_remote", "reliable")
func _receive_players(list: Dictionary) -> void:
	players = list
	players_changed.emit()


func _broadcast_players() -> void:
	if not multiplayer.get_peers().is_empty():
		_receive_players.rpc(players)
	players_changed.emit()


## Server only. A player's health hit 0. Families live in the player's own
## save, so the server tells them, then drops them from the session.
func player_died(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	print("Peer %d died" % id)
	progress.erase(id)
	_you_died.rpc_id(id)
	if players.erase(id):
		_broadcast_players()


## Server only. Marriage (design log 0030): tell the player to update their save.
func heir_born_on_server(id: int, heir: Dictionary) -> void:
	if players.has(id):
		players[id].sides = heir.sides
		players[id].kind = heir.kind
		players[id].apex = heir.apex
		players[id].luck = heir.luck
		players[id].generation += 1
		_broadcast_players()
	_heir_born.rpc_id(id, heir)


## Server -> the player who died. Dying without an heir ends the family
## (design log 0015).
@rpc("authority", "call_local", "reliable")
func _you_died() -> void:
	var family := FamilyStore.active_family()
	var reason := "You died."
	if family != null:
		family.extinct = true
		FamilyStore.save_slot(FamilyStore.active_slot)
		reason = "The %s family has ended: died without an heir." % family.family_name
	leave()
	session_ended.emit(reason)


## Server -> the player who married.
@rpc("authority", "call_local", "reliable")
func _heir_born(heir: Dictionary) -> void:
	var family := FamilyStore.active_family()
	if family != null:
		family.generation += 1
		family.sides = heir.sides
		family.kind = heir.kind
		family.apex = heir.apex
		family.luck = heir.luck
		family.progress = {}  # the heir starts fresh; the world saves it from here
		FamilyStore.save_slot(FamilyStore.active_slot)
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
	if clean.kind == "isosceles":
		if clean.sides != 3:
			clean.kind = "regular"
		else:
			clean.apex = clampi(raw_apex if raw_apex is int else Family.START_APEX,
					Family.START_APEX, Family.EQUILATERAL_APEX - Family.APEX_STEP)
	return clean
