class_name PlayerChat
extends Node
## Chat and admin commands (PlayerShape's "Chat", design logs 0124, 0125).
##
## The owner sends each line it types. The server passes a plain line to
## everyone in the same part of the world (room_of), who see it in their
## chat log and in a bubble over the speaker. A line starting with "\" is an
## admin command instead (AdminConsole): only the sender sees the answer.
## \diagnostics (log 0155) never goes out as a line: the owner pings the
## server and writes up the answers (Diagnostics). \diag live keeps
## pinging, once a second, for the HUD's live panel; \simulate lag slows
## this game's connection (log 0159). Neither is sent either.

const MAX_LENGTH := 160
const BURST := 5  # lines...
const BURST_TIME := 5.0  # ...per this many seconds, then "too fast"
const PINGS := 5  # \diagnostics sends this many...
const PING_GAP := 0.2  # ...this many seconds apart...
const PING_WAIT := 2.0  # ...and waits this much longer for the last answers
const PING_MIN_MSEC := 50  # server: answers at most one ping per this long
const LIVE_EVERY := 1.0  # s between \diag live's pings
const LIVE_PINGS := 5  # it shows the latest this many

var player: PlayerShape
var _recent: Array[int] = []  # server: msec of this player's last lines
var _last_ping := -PING_MIN_MSEC  # server: msec of the last ping answered
# Owner, while \diagnostics runs:
var _pinging := false
var _ping_clock := 0.0
var _pings_sent := 0
var _rtts: Array[float] = []  # round trips, ms
var _server_info := {}
## \diag live is on: for this game, not one shape (a new family keeps it).
static var live := false
# Owner, while it's on:
var live_rtts: Array[float] = []
var live_server := {}
var _live_clock := LIVE_EVERY  # the first ping goes at once


func _ready() -> void:
	_update_processing()  # only while pinging


## Owner. Sends a typed line to the server, or runs it if it's one of
## Diagnostics' commands.
func send_line(text: String) -> void:
	var asked := Diagnostics.parse(text)
	if asked.is_empty():
		_submit_line.rpc_id(1, text)
		return
	match asked.get("do", ""):
		"report":
			run_diagnostics()
		"live":
			set_live(not live)
			_notice("Live diagnostics %s." % ("on, top right" if live else "off"))
		"simulate":
			if Net.lag_peer != null:
				if asked.has("lag"):
					Net.lag_peer.simulate(asked.lag, asked.jitter)
				if asked.has("stall"):
					Net.lag_peer.simulate_stalls(asked.stall, asked.every)
			_notice(Diagnostics.simulate_answer())
		_:
			_notice(asked.error)


## Owner. The HUD's live panel on or off (\diag live).
func set_live(on: bool) -> void:
	live = on
	live_rtts.clear()
	live_server = {}
	_live_clock = LIVE_EVERY  # the first ping goes now
	_update_processing()


func _update_processing() -> void:
	set_process(_pinging or (live and Net.mode == Net.Mode.JOIN and player != null and player.is_local()))


func _notice(text: String) -> void:
	get_tree().call_group(Hud.GROUP, "chat_notice", text)


## Owner. Pings the server PINGS times, then shows Diagnostics.report.
func run_diagnostics() -> void:
	if _pinging:
		return
	_pinging = true
	_ping_clock = 0.0
	_pings_sent = 0
	_rtts.clear()
	_server_info = {}
	_update_processing()


func _process(delta: float) -> void:
	if live and Net.mode == Net.Mode.JOIN and player.is_local():
		_live_clock += delta
		if _live_clock >= LIVE_EVERY:
			_live_clock = 0.0
			_ping.rpc_id(1, _msec(), true, true)
	if not _pinging:
		return
	_ping_clock += delta
	if _pings_sent < PINGS and _ping_clock >= _pings_sent * PING_GAP:
		_pings_sent += 1
		_ping.rpc_id(1, _msec(), _pings_sent == PINGS, false)
	if _rtts.size() >= PINGS or _ping_clock > PINGS * PING_GAP + PING_WAIT:
		_pinging = false
		_update_processing()
		_notice(Diagnostics.report(_rtts, _pings_sent, _server_info, player))


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


## Server. Answers a \diagnostics ping; the last one (and each live one)
## also gets the server's numbers. `live`: \diag live's, not the report's.
@rpc("any_peer", "call_local", "reliable")
func _ping(sent: Variant, last: Variant, live_ping: Variant) -> void:
	if not player.from_owner() or not (sent is float or sent is int):
		return
	var now := Time.get_ticks_msec()
	if now - _last_ping < PING_MIN_MSEC:
		return
	_last_ping = now
	_pong.rpc_id(player.peer_id, float(sent), Diagnostics.server_info() if last == true else {}, live_ping == true)


@rpc("authority", "call_local", "reliable")
func _pong(sent: float, info: Dictionary, live_ping: bool) -> void:
	if live_ping:
		if not live:
			return
		live_rtts.append(_msec() - sent)
		if live_rtts.size() > LIVE_PINGS:
			live_rtts.pop_front()
		if not info.is_empty():
			live_server = info
		return
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
