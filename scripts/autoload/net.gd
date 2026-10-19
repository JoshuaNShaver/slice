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
## Clients and servers must match exactly to play together (design log
## 0109). Set in project.godot (application/config/version); bump it with
## any change an older client or server couldn't play with.
var version: String = str(ProjectSettings.get_setting("application/config/version", ""))

## Peer id -> {"family", "sides", "kind", "apex", "luck", "generation"}. Set by the server.
var players: Dictionary = {}
## Server only. Peer id -> the saved progress they joined with (design log
## 0038), checked by PlayerShape.sanitize_progress. Not sent to other players.
var progress: Dictionary = {}
## Server only. Peer id -> the house chests they joined with (design log
## 0064), checked like progress.
var chests: Dictionary = {}
var mode := Mode.OFFLINE
var port := DEFAULT_PORT
var in_session := false
## A message for the main menu to show after returning to it (e.g. lost connection).
var last_message := ""

var _local_info: Dictionary = {}
## Server only. Peer id -> "ip:port", for logging which client a network
## error might be about.
var _addresses: Dictionary = {}
## Server only. Peer ids whose version matched; only they may register.
var _verified: Dictionary = {}
var _handshake: Node


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_handshake = preload("res://scripts/autoload/handshake.gd").new()
	_handshake.name = "Handshake"
	add_child(_handshake)


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
	print("Server listening on port %d, version %s" % [on_port, version])
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
	chests.clear()
	in_session = false
	_local_info = {}
	_addresses.clear()
	_verified.clear()


func _begin_as_server(info: Dictionary) -> void:
	in_session = true
	if not info.is_empty():
		_admit(multiplayer.get_unique_id(), info)
	session_started.emit()
	players_changed.emit()


## Connected, but not in yet: the server checks the version first.
func _on_connected_to_server() -> void:
	_handshake.say_hello()


## Client. The server accepted our version.
func on_welcomed() -> void:
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
	if was_in:
		session_ended.emit(reason)
	else:
		session_failed.emit(reason)


## Server only.
func verify(id: int) -> void:
	_verified[id] = true


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
		_register.rpc_id(1, _local_info)


func _on_connection_failed() -> void:
	leave()
	session_failed.emit("Couldn't reach the server.")


func _on_server_disconnected() -> void:
	if mode == Mode.HOST and in_session:
		_reopen_server()
		return
	var was_in := in_session
	leave()
	if was_in:
		session_ended.emit("Lost connection to the server.")
	else:
		session_failed.emit("The server closed the connection.")


## Host only. ENet shuts the whole server down when a send fails (e.g. a
## client it can't reach), and SceneMultiplayer reports that as
## server_disconnected. Rather than ending the session (which sent a
## dedicated server back to the menu, restarting the world), log why, drop
## the remote players and listen again on the same port. The world, and
## a host's own player, carry on.
func _reopen_server() -> void:
	var known := []
	for id: int in _addresses:
		known.append("peer %d at %s" % [id, _addresses[id]])
	push_warning(("Server network error: ENet couldn't send to a client, so the server "
			+ "connection closed. Remote clients: %s. On macOS, check System Settings > "
			+ "Privacy & Security > Local Network allows Godot (and your terminal). "
			+ "Reopening port %d; remote players were dropped and can rejoin.")
			% [", ".join(known) if not known.is_empty() else "none fully connected yet", port])
	_addresses.clear()
	var dropped := false
	for id: int in players.keys():
		if id != 1:
			players.erase(id)
			progress.erase(id)
			chests.erase(id)
			dropped = true
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("Couldn't reopen port %d (%s); ending the session." % [port, error_string(err)])
		leave()
		session_ended.emit("The server's network failed.")
		return
	multiplayer.multiplayer_peer = peer
	print("Server listening on port %d again" % port)
	if dropped:
		players_changed.emit()


func _on_peer_connected(id: int) -> void:
	if mode != Mode.HOST:
		return
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var packet_peer := peer.get_peer(id) if peer != null else null
	if packet_peer != null:
		_addresses[id] = "%s:%d" % [packet_peer.get_remote_address(), packet_peer.get_remote_port()]
		print("Peer %d connecting from %s" % [id, _addresses[id]])
	_handshake.expect_hello(id)


func _on_peer_disconnected(id: int) -> void:
	_addresses.erase(id)
	_verified.erase(id)
	progress.erase(id)
	chests.erase(id)
	if multiplayer.is_server() and players.erase(id):
		print("Peer %d left" % id)
		_broadcast_players()


## Client -> server: "this is who I am".
@rpc("any_peer", "call_remote", "reliable")
func _register(info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not is_verified(id):
		kick(id)
		return
	_admit(id, info)
	print("Peer %d joined as the %s family" % [id, players[id].family])
	_broadcast_players()


## Server only. Never trust what a client sends.
func _admit(id: int, info: Dictionary) -> void:
	players[id] = _sanitize(info)
	var raw: Variant = info.get("progress", {})
	progress[id] = PlayerShape.sanitize_progress(raw if raw is Dictionary else {})
	var raw_chest: Variant = info.get("chest", [])
	chests[id] = PlayerShape._clean_items(raw_chest if raw_chest is Array else [], PlayerShape.CHEST_SLOTS)


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
	chests.erase(id)
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
	if clean.kind == "isosceles" and clean.sides != 3:
		clean.kind = "regular"
	clean.apex = Family.clean_apex(clean.sides, clean.kind,
			raw_apex if raw_apex is int else Family.START_APEX)
	return clean
