class_name Diagnostics
extends RefCounted
## \diagnostics (design log 0155): anyone can run it. PlayerChat pings the
## server a few times; the last answer brings the server's own numbers
## (server_info). report() adds this machine's and writes it all up.
## \diag live shows live_text() while you play; \simulate lag adds lag to
## your own connection (LagPeer) to try the game slower (log 0159).

## What players type. Handled by PlayerChat, never sent as a chat line.
const COMMANDS: Array[String] = ["\\diagnostics", "\\diag"]
const HELP := "your ping, framerate and connection (add live to keep it on screen)"
const SIMULATE := "\\simulate"
const SIMULATE_HELP := "lag <ms> [jitter ms]: adds lag to your connection, to test (lag off stops)"
const MAX_LAG := 5000.0  # ms
const RENDERERS := {"forward_plus": "Forward+", "mobile": "Mobile", "gl_compatibility": "Compatibility"}


static func is_command(line: String) -> bool:
	return not parse(line).is_empty()


## What a typed line asks for: {"do": "report"}, {"do": "live"},
## {"do": "lag", "lag": ms, "jitter": ms}, {"error": text}, or {} if it's
## not one of these.
static func parse(line: String) -> Dictionary:
	var words := line.strip_edges().to_lower().split(" ", false)
	if words.is_empty():
		return {}
	if words[0] in COMMANDS:
		if words.size() == 1:
			return {"do": "report"}
		if words.size() == 2 and words[1] == "live":
			return {"do": "live"}
		return {"error": "Try %s, or %s live to keep it on screen." % [COMMANDS[0], COMMANDS[1]]}
	if words[0] != SIMULATE:
		return {}
	var usage := {"error": "Try %s lag 150 (ms), %s lag 150 30 (with jitter), or %s lag off." % [SIMULATE, SIMULATE, SIMULATE]}
	if words.size() < 2 or words[1] != "lag":
		return usage
	if words.size() == 3 and words[2] in ["off", "0"]:
		return {"do": "lag", "lag": 0.0, "jitter": 0.0}
	if words.size() < 3 or words.size() > 4 or not words[2].is_valid_float() \
			or (words.size() == 4 and not words[3].is_valid_float()):
		return usage
	var lag := clampf(words[2].to_float(), 0.0, MAX_LAG)
	var jitter := clampf(words[3].to_float(), 0.0, lag / 2.0) if words.size() == 4 else 0.0
	return {"do": "lag", "lag": lag, "jitter": jitter}


## Your answer to \simulate lag, after setting it.
static func lag_answer(lag: float, jitter: float) -> String:
	if Net.lag_peer == null:
		return "No connection to slow down: %s." % ("you're hosting" if Net.mode == Net.Mode.HOST else "you're offline")
	if lag <= 0.0:
		return "Simulated lag off."
	return "Simulating %d ms of lag%s, on your connection only. %s lag off to stop." % [
			roundi(lag), " (give or take %d ms each way)" % roundi(jitter) if jitter > 0.0 else "", SIMULATE]


## The simulated lag, for reports: "" if none.
static func _simulated() -> String:
	if Net.lag_peer == null or Net.lag_peer.lag_ms <= 0.0:
		return ""
	var jitter := Net.lag_peer.jitter_ms
	return "simulated +%d ms%s" % [roundi(Net.lag_peer.lag_ms), " ±%d" % roundi(jitter) if jitter > 0.0 else ""]


## The live panel (\diag live): a few short lines. `pings` are the latest
## round trips in ms, `server` the server's latest info.
static func live_text(pings: Array[float], server: Dictionary, me: PlayerShape) -> String:
	var lines: Array[String] = ["%d fps  frame %.1f ms" % [
			Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0]]
	if Net.mode != Net.Mode.JOIN:
		lines.append("no network (%s)" % ("hosting" if Net.mode == Net.Mode.HOST else "offline"))
		return "\n".join(lines)
	var ping := "ping …"
	if not pings.is_empty():
		var total := 0.0
		for p in pings:
			total += p
		ping = "ping %d ms (%d-%d)" % [roundi(total / pings.size()), roundi(pings.min()), roundi(pings.max())]
	var sim := _simulated()
	lines.append(ping + ("  " + sim if sim != "" else ""))
	var net := me.net_stats() if me != null else {}
	if not net.is_empty():
		lines.append("updates %.0f/s  gap %d ms  late %d ms" % [
				net.rate, roundi(net.gap * 1000.0), roundi(net.late * 1000.0)])
	if not server.is_empty():
		lines.append("server %d fps  physics %.1f/%.1f ms  %d on" % [
				server.get("fps", 0), server.get("physics_ms", 0.0),
				1000.0 / maxi(int(server.get("ticks", 60)), 1), server.get("players", 0)])
	return "\n".join(lines)


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
		var sim := _simulated()
		lines.append("  Ping: " + _pings(pings, sent) + (", " + sim if sim != "" else ""))
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
