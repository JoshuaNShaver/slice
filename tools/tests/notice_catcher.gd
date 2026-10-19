extends Node
## For online_checks.gd: joins the HUD's group and keeps what the server
## answers to chat commands (PlayerChat calls chat_notice on the HUD group).

var notices: Array = []


func _ready() -> void:
	add_to_group(Hud.GROUP)


func chat_notice(text: String) -> void:
	notices.append(text)


func hear(_speaker_id: int, _speaker: String, _text: String) -> void:
	pass
