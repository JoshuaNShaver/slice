class_name PlayerChat
extends Node
## Chat and admin commands (PlayerShape's "Chat", design logs 0124, 0125).
##
## The owner sends each line it types. The server passes a plain line to
## everyone in the same part of the world (room_of), who see it in their
## chat log and in a bubble over the speaker. A line starting with "\" is an
## admin command instead (AdminConsole): only the sender sees the answer.

const MAX_LENGTH := 160
const BURST := 5  # lines...
const BURST_TIME := 5.0  # ...per this many seconds, then "too fast"

var player: PlayerShape
var _recent: Array[int] = []  # server: msec of this player's last lines


## Owner. Sends a typed line to the server.
func send_line(text: String) -> void:
	_submit_line.rpc_id(1, text)


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
