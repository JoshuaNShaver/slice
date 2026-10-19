class_name PlayerScreen
extends Node
## The server's messages to one player's HUD (PlayerShape's "Screen"): lines
## spoken to you, the General's and the Quartermaster's panels, your house's
## chests and the countdown popup. Server-side calls; each runs on the
## owner's machine.

var player: PlayerShape


## Server only. Shows this player a line, e.g. an NPC's words.
func tell(speaker: String, line: String) -> void:
	_told.rpc_id(player.peer_id, speaker, line)


@rpc("authority", "call_local", "reliable")
func _told(speaker: String, line: String) -> void:
	get_tree().call_group(Hud.GROUP, "say", speaker, line)


## Server only. Opens a HUD panel on your screen: "orders" (the General's
## missions) or "shop" (the Quartermaster's stock).
func open_panel(panel: String) -> void:
	_panel_opened.rpc_id(player.peer_id, panel)


@rpc("authority", "call_local", "reliable")
func _panel_opened(panel: String) -> void:
	get_tree().call_group(Hud.GROUP, "open_panel", panel)


## Server only. Opens your house's chests on your screen (design log 0064).
func open_storage() -> void:
	_storage_opened.rpc_id(player.peer_id)


@rpc("authority", "call_local", "reliable")
func _storage_opened() -> void:
	get_tree().call_group(Hud.GROUP, "open_storage")


## Server only. Shows this player a countdown popup with a Ready button
## (design log 0081): a muster or the trip home. An empty title hides it.
## `ready_count` of `total` are ready (total 0: no squad count to show).
## `button` relabels Ready, e.g. "Report back" (design log 0089).
func show_countdown(title: String, seconds: float, ready_count: int, total: int, you_ready: bool,
		button := "") -> void:
	_countdown_shown.rpc_id(player.peer_id, title, seconds, ready_count, total, you_ready, button)


@rpc("authority", "call_local", "reliable")
func _countdown_shown(title: String, seconds: float, ready_count: int, total: int, you_ready: bool,
		button: String) -> void:
	get_tree().call_group(Hud.GROUP, "show_countdown", title, seconds, ready_count, total, you_ready, button)
