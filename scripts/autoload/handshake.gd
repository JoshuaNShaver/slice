extends Node
## The version check on joining (design log 0109). A child of Net, at
## /root/Net/Handshake.
##
## Don't add, remove, rename or change these RPCs: builds of every version
## must still understand each other here, so an old client gets the
## "please update" message instead of a broken connection.

## Server only. How long a client has to say hello before it's dropped.
const HELLO_TIMEOUT := 10.0
## Server only. How long a turned-away client has to read why before the
## server closes the connection (the client normally leaves first).
const REJECT_GRACE := 2.0


## Client: called once connected.
func say_hello() -> void:
	_hello.rpc_id(1, Net.version)


## Server: called when a peer connects.
func expect_hello(id: int) -> void:
	await get_tree().create_timer(HELLO_TIMEOUT).timeout
	if Net.is_connected_peer(id) and not Net.is_verified(id):
		print("Peer %d never said hello; dropping it" % id)
		Net.kick(id)


## Client -> server: "I run this version".
@rpc("any_peer", "call_remote", "reliable")
func _hello(version: Variant) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	var theirs := str(version)
	if theirs == Net.version:
		Net.verify(id)
		_welcome.rpc_id(id)
		return
	print("Peer %d runs version %s, not %s; turning it away" % [id, theirs, Net.version])
	turn_away(id, ("This server runs version %s; you have %s. Please update "
			+ "the game (in a browser, reload the page).") % [Net.version, theirs])


## Server: tells a client why, then closes its connection.
func turn_away(id: int, reason: String) -> void:
	_rejected.rpc_id(id, reason)
	await get_tree().create_timer(REJECT_GRACE).timeout
	if Net.is_connected_peer(id):
		Net.kick(id)


## Server -> client: versions match, carry on.
@rpc("authority", "call_remote", "reliable")
func _welcome() -> void:
	Net.on_welcomed()


## Server -> client: turned away, and why.
@rpc("authority", "call_remote", "reliable")
func _rejected(reason: Variant) -> void:
	Net.on_rejected(str(reason))
