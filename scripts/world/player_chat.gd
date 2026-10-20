class_name PlayerChat
extends Node
## Chat and admin commands (PlayerShape's "Chat", design logs 0124, 0125).
##
## The owner sends each line it types. The server passes a plain line to
## everyone in the same part of the world (room_of), who see it in their
## chat log and in a bubble over the speaker. A line starting with "\" is an
## admin command instead (AdminConsole): only the sender sees the answer.
## \diagnostics (log 0155) never goes out as a line: the owner pings the
## server and writes up the answers (Diagnostics).

const MAX_LENGTH := 160
const BURST := 5  # lines...
const BURST_TIME := 5.0  # ...per this many seconds, then "too fast"
const PINGS := 5  # \diagnostics sends this many...
const PING_GAP := 0.2  # ...this many seconds apart...
const PING_WAIT := 2.0  # ...and waits this much longer for the last answers
const PING_MIN_MSEC := 50  # server: answers at most one ping per this long

var player: PlayerShape
var _recent: Array[int] = []  # server: msec of this player's last lines
var _last_ping := -PING_MIN_MSEC  # server: msec of the last ping answered
# Owner, while \diagnostics runs:
var _pinging := false
var _ping_clock := 0.0
var _pings_sent := 0
var _rtts: Array[float] = []  # round trips, ms
var _server_info := {}


func _ready() -> void:
	set_process(false)  # only while pinging


## Owner. Sends a typed line to the server.
func send_line(text: String) -> void:
	if Diagnostics.is_command(text):
		run_diagnostics()
		return
	_submit_line.rpc_id(1, text)


## Owner. Pings the server PINGS times, then shows Diagnostics.report.
func run_diagnostics() -> void:
	if _pinging:
		return
	_pinging = true
	_ping_clock = 0.0
	_pings_sent = 0
	_rtts.clear()
	_server_info = {}
	set_process(true)


func _process(delta: float) -> void:
	_ping_clock += delta
	if _pings_sent < PINGS and _ping_clock >= _pings_sent * PING_GAP:
		_pings_sent += 1
		_ping.rpc_id(1, _msec(), _pings_sent == PINGS)
	if _rtts.size() >= PINGS or _ping_clock > PINGS * PING_GAP + PING_WAIT:
		_pinging = false
		set_process(false)
		var text := Diagnostics.report(_rtts, _pings_sent, _server_info, player)
		get_tree().call_group(Hud.GROUP, "chat_notice", text)


static func _msec() -> float:
	return Time.get_ticks_usec() / 1000.0


## Server only. Answers this player alone, in their chat log.
func reply(text: String) -> void:
	_replied.rpc_id(player.peer_id, text)


## Who can hear a line said at `pos`: the overworld, the underworld, or one
## squad's mission.
static func room_of(pos: Vector2) -> String:
	var slot := Regions.mission_slot_at(pos)
	if slot >= 0:
		return "mission %d" % slot
	return "underworld" if Regions.is_underworld(pos) else "overworld"


## Server only. A player's name in chat: their username (online), else
## their family's name.
static func name_of(p: PlayerShape) -> String:
	var session: Dictionary = Net.accounts.sessions.get(p.peer_id, {})
	var username: String = session.get("username", "")
	return username if username != "" else "The %s family" % p.family_name


## One line of plain text: no line breaks or control characters, trimmed,
## at most MAX_LENGTH long.
static func clean(text: String) -> String:
	var out := ""
	for c in text:
		out += " " if c.unicode_at(0) < 32 or c.unicode_at(0) == 127 else c
	return out.strip_edges().left(MAX_LENGTH)


@rpc("any_peer", "call_local", "reliable")
func _submit_line(text: Variant) -> void:
	if not player.from_owner() or not text is String:
		return
	var line := clean(text)
	if line == "":
		return
	if _too_fast():
		reply("You're talking too fast.")
		return
	if line.begins_with(AdminConsole.ESCAPE):
		reply(AdminConsole.run(player, line))
		return
	var speaker := name_of(player)
	var room := room_of(player.position)
	for node in get_tree().get_nodes_in_group(PlayerShape.GROUP):
		var p := node as PlayerShape
		if room_of(p.position) == room:
			p.chat._heard.rpc_id(p.peer_id, player.peer_id, speaker, line)


## Server. Answers a \diagnostics ping; the last one also gets the server's
## numbers.
@rpc("any_peer", "call_local", "reliable")
func _ping(sent: Variant, last: Variant) -> void:
	if not player.from_owner() or not (sent is float or sent is int):
		return
	var now := Time.get_ticks_msec()
	if now - _last_ping < PING_MIN_MSEC:
		return
	_last_ping = now
	_pong.rpc_id(player.peer_id, float(sent), Diagnostics.server_info() if last == true else {})


@rpc("authority", "call_local", "reliable")
func _pong(sent: float, info: Dictionary) -> void:
	if not _pinging:
		return  # a late answer from a finished run
	_rtts.append(_msec() - sent)
	if not info.is_empty():
		_server_info = info


func _too_fast() -> bool:
	var now := Time.get_ticks_msec()
	while not _recent.is_empty() and now - _recent[0] > BURST_TIME * 1000.0:
		_recent.pop_front()
	if _recent.size() >= BURST:
		return true
	_recent.append(now)
	return false


@rpc("authority", "call_local", "reliable")
func _heard(speaker_id: int, speaker: String, line: String) -> void:
	get_tree().call_group(Hud.GROUP, "hear", speaker_id, speaker, line)


@rpc("authority", "call_local", "reliable")
func _replied(text: String) -> void:
	get_tree().call_group(Hud.GROUP, "chat_notice", text)
