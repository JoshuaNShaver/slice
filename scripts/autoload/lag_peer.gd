class_name LagPeer
extends MultiplayerPeerExtension
## A client's connection with lag added, for \simulate lag (design log
## 0159). Wraps the real peer: each packet, going out or coming in, waits
## half the lag (give or take the jitter) before it moves on. Packets keep
## their order, as they would over WebSocket. With no lag set they pass
## straight through.

var inner: MultiplayerPeer
var lag_ms := 0.0  # added round trip
var jitter_ms := 0.0  # each way, give or take

var _out: Array[Dictionary] = []  # {at, data, peer, channel, mode}, oldest first
var _in: Array[Dictionary] = []
var _out_last := 0  # usec the newest queued packet leaves, so order holds
var _in_last := 0
var _target := 0
var _channel := 0
var _mode := TRANSFER_MODE_RELIABLE
var _rng := RandomNumberGenerator.new()


func _init(wrapped: MultiplayerPeer) -> void:
	inner = wrapped
	inner.peer_connected.connect(func(id: int) -> void: peer_connected.emit(id))
	inner.peer_disconnected.connect(func(id: int) -> void: peer_disconnected.emit(id))
	_rng.randomize()


## Sets the lag; 0 turns it off. Packets already waiting keep their times.
func simulate(lag: float, jitter := 0.0) -> void:
	lag_ms = maxf(lag, 0.0)
	jitter_ms = clampf(jitter, 0.0, lag_ms / 2.0)


## When a packet queued now moves on: half the lag, jitter either way, and
## never before the one queued ahead of it.
func _release_at(last: int) -> int:
	var wait := lag_ms / 2.0 + _rng.randf_range(-jitter_ms, jitter_ms)
	return maxi(last, Time.get_ticks_usec() + int(maxf(wait, 0.0) * 1000.0))


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if lag_ms <= 0.0 and _out.is_empty():
		return _send(buffer, _target, _channel, _mode)
	_out_last = _release_at(_out_last)
	_out.append({"at": _out_last, "data": buffer, "peer": _target, "channel": _channel, "mode": _mode})
	return OK


func _send(data: PackedByteArray, peer: int, channel: int, mode: TransferMode) -> Error:
	inner.set_target_peer(peer)
	inner.transfer_channel = channel
	inner.transfer_mode = mode
	return inner.put_packet(data)


func _poll() -> void:
	var now := Time.get_ticks_usec()
	while not _out.is_empty() and _out[0].at <= now:
		var p: Dictionary = _out.pop_front()
		_send(p.data, p.peer, p.channel, p.mode)
	inner.poll()
	while inner.get_available_packet_count() > 0:
		# Peer, channel and mode describe the next packet, so read them first.
		var p := {"peer": inner.get_packet_peer(), "channel": inner.get_packet_channel(),
				"mode": inner.get_packet_mode()}
		p.data = inner.get_packet()
		_in_last = _release_at(_in_last) if lag_ms > 0.0 or not _in.is_empty() else now
		p.at = _in_last
		_in.append(p)


func _get_available_packet_count() -> int:
	var now := Time.get_ticks_usec()
	var count := 0
	for p in _in:
		if p.at > now:
			break
		count += 1
	return count


func _get_packet_script() -> PackedByteArray:
	return _in.pop_front().data if not _in.is_empty() else PackedByteArray()


func _get_packet_peer() -> int:
	return _in[0].peer if not _in.is_empty() else 0


func _get_packet_channel() -> int:
	return _in[0].channel if not _in.is_empty() else 0


func _get_packet_mode() -> TransferMode:
	return _in[0].mode if not _in.is_empty() else TRANSFER_MODE_RELIABLE


func _get_max_packet_size() -> int:
	return 1 << 24


func _set_target_peer(peer: int) -> void:
	_target = peer


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel


func _set_transfer_mode(mode: TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> TransferMode:
	return _mode


func _get_unique_id() -> int:
	return inner.get_unique_id()


func _is_server() -> bool:
	return inner.get_unique_id() == 1


func _is_server_relay_supported() -> bool:
	return inner.is_server_relay_supported()


func _get_connection_status() -> ConnectionStatus:
	return inner.get_connection_status()


func _set_refuse_new_connections(enable: bool) -> void:
	inner.refuse_new_connections = enable


func _is_refusing_new_connections() -> bool:
	return inner.refuse_new_connections


func _disconnect_peer(peer: int, force: bool) -> void:
	inner.disconnect_peer(peer, force)


func _close() -> void:
	_out.clear()
	_in.clear()
	inner.close()
