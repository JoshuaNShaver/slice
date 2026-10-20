class_name Diagnostics
extends RefCounted
## \diagnostics (design log 0155): anyone can run it. PlayerChat pings the
## server a few times; the last answer brings the server's own numbers
## (server_info). report() adds this machine's and writes it all up.

## What players type. Handled by PlayerChat, never sent as a chat line.
const COMMANDS: Array[String] = ["\\diagnostics", "\\diag"]
const HELP := "your ping, framerate and connection"
const RENDERERS := {"forward_plus": "Forward+", "mobile": "Mobile", "gl_compatibility": "Compatibility"}


static func is_command(line: String) -> bool:
	return line.strip_edges().to_lower() in COMMANDS


## Server only: how the server is keeping up.
static func server_info() -> Dictionary:
	return {
		"version": Net.version,
		"fps": Engine.get_frames_per_second(),
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"ticks": Engine.physics_ticks_per_second,
		"players": Net.players.size(),
		"enemies": Engine.get_main_loop().get_nodes_in_group(Enemy.GROUP).size(),
		"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"uptime": Time.get_ticks_msec() / 1000.0,
	}


## The write-up. `pings` are round trips in ms, `sent` how many went out,
## `server` the server's info ({} if it never answered), `me` your shape.
static func report(pings: Array[float], sent: int, server: Dictionary, me: PlayerShape) -> String:
	var lines: Array[String] = ["Diagnostics (version %s, %s)" % [Net.version, _platform()]]
	var window := DisplayServer.window_get_size()
	lines.append("  You: %d fps (%s), frame %.1f ms, %s, %dx%d" % [
		Engine.get_frames_per_second(), _cap(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"Low" if Graphics.low else "High", window.x, window.y])
	if Net.mode != Net.Mode.JOIN:
		lines.append("  Network: none, %s runs the world on this machine." % (
				"you're hosting, so this game" if Net.mode == Net.Mode.HOST else "offline, the game"))
	else:
		lines.append("  Ping: " + _pings(pings, sent))
		var net := me.net_stats() if me != null else {}
		if net.is_empty():
			lines.append("  Updates: none yet")
		else:
			lines.append("  Updates: %.0f a second, longest gap %d ms, late by %d ms on average (worst %d), last %d s" % [
				net.rate, roundi(net.gap * 1000.0), roundi(net.late * 1000.0), roundi(net.late_max * 1000.0),
				roundi(NetSmoother.STATS_WINDOW)])
	if server.is_empty():
		lines.append("  Server: didn't answer")
	else:
		lines.append("  Server: %d fps, physics %.1f ms a step (of %.1f), %s, %s, %d MB, up %s%s" % [
			server.get("fps", 0), server.get("physics_ms", 0.0), 1000.0 / maxi(int(server.get("ticks", 60)), 1),
			_count(server.get("players", 0), "player"), _count(server.get("enemies", 0), "enemy", "enemies"),
			roundi(server.get("memory_mb", 0.0)),
			_duration(server.get("uptime", 0.0)),
			"" if server.get("version", "") == Net.version else ", version %s" % server.get("version", "?")])
	return "\n".join(lines)


static func _pings(pings: Array[float], sent: int) -> String:
	if pings.is_empty():
		return "no answer"
	var total := 0.0
	for p in pings:
		total += p
	var text := "%d ms (%d to %d over %d)" % [roundi(total / pings.size()), roundi(pings.min()),
			roundi(pings.max()), pings.size()]
	if pings.size() < sent:
		text += ", %d didn't come back in time" % (sent - pings.size())
	return text


static func _platform() -> String:
	var where := "web" if OS.has_feature("web") else OS.get_name()
	var renderer := RenderingServer.get_current_rendering_method()
	return "%s, %s" % [where, RENDERERS.get(renderer, renderer)]


static func _count(n: int, one: String, many := "") -> String:
	return "%d %s" % [n, one if n == 1 else (many if many != "" else one + "s")]


static func _cap() -> String:
	return "no cap" if Engine.max_fps <= 0 else "cap %d" % Engine.max_fps


## 3725 -> "1h 2m".
static func _duration(seconds: float) -> String:
	var s := int(seconds)
	if s >= 3600:
		return "%dh %dm" % [s / 3600, s % 3600 / 60]
	if s >= 60:
		return "%dm %ds" % [s / 60, s % 60]
	return "%ds" % s
