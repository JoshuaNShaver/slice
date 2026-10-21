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
const SIMULATE_HELP := "lag <ms> [jitter] | stalls <ms> [every <s>] | prod | off: a slower connection, to test"
## \simulate prod (log 0167): like the live server from here, a steady
## ~40 ms ping with a stall now and then.
const PROD := {"lag": 35.0, "jitter": 1.0, "stall": 160.0, "every": 5.0}
const STALL_EVERY := 5.0  # s between stalls when not given
const MAX_LAG := 5000.0  # ms
## A frame longer than this is a hitch, kept for `worst_frame` (log 0160).
const HITCH_MS := 25.0
const HITCH_WINDOW := 10.0  # seconds of hitches remembered
const RENDERERS := {"forward_plus": "Forward+", "mobile": "Mobile", "gl_compatibility": "Compatibility"}


# [time s, frame ms] of each recent hitch, oldest first. World notes every frame.
static var _hitches: Array[Vector2] = []


## Called by World each frame, on the server and clients alike.
static func note_frame(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if delta * 1000.0 > HITCH_MS:
		_hitches.append(Vector2(now, delta * 1000.0))
	while not _hitches.is_empty() and now - _hitches[0].x > HITCH_WINDOW:
		_hitches.pop_front()


## This machine's longest frame in the last HITCH_WINDOW, in ms; 0 if none
## went over HITCH_MS.
static func worst_frame() -> float:
	var worst := 0.0
	for h in _hitches:
		worst = maxf(worst, h.y)
	return worst


## "worst 40 ms" or "" when there were no hitches.
static func _worst(ms: float) -> String:
	return "" if ms <= 0.0 else "worst %d ms" % roundi(ms)


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
	return _parse_simulate(words)


## \simulate lag <ms> [jitter] | stalls <ms> [every <s>] | prod | off
## (logs 0159, 0167): {"do": "simulate", ...what to set}, or {"error"}.
static func _parse_simulate(words: PackedStringArray) -> Dictionary:
	var usage := {"error": "Try %s lag 150 [30 jitter], %s stalls 160 [every 5 s], %s prod, or %s off." % [
			SIMULATE, SIMULATE, SIMULATE, SIMULATE]}
	if words.size() == 2 and words[1] == "off":
		return {"do": "simulate", "lag": 0.0, "jitter": 0.0, "stall": 0.0, "every": 0.0}
	if words.size() == 2 and words[1] == "prod":
		return {"do": "simulate", "lag": PROD.lag, "jitter": PROD.jitter, "stall": PROD.stall, "every": PROD.every}
	if words.size() < 3 or words[1] not in ["lag", "stalls"]:
		return usage
	if words.size() == 3 and words[2] in ["off", "0"]:
		if words[1] == "lag":
			return {"do": "simulate", "lag": 0.0, "jitter": 0.0}
		return {"do": "simulate", "stall": 0.0, "every": 0.0}
	var numbers: Array[float] = []
	for w in words.slice(2):
		if w == "every" and words[1] == "stalls":
			continue
		if not w.is_valid_float():
			return usage
		numbers.append(w.to_float())
	if words[1] == "lag":
		if numbers.size() > 2:
			return usage
		var lag := clampf(numbers[0], 0.0, MAX_LAG)
		var jitter := clampf(numbers[1], 0.0, lag / 2.0) if numbers.size() == 2 else 0.0
		return {"do": "simulate", "lag": lag, "jitter": jitter}
	if numbers.size() > 2:
		return usage
	return {"do": "simulate", "stall": clampf(numbers[0], 0.0, MAX_LAG),
			"every": maxf(numbers[1], 0.5) if numbers.size() == 2 else STALL_EVERY}


## What \simulate set, for its answer.
static func simulate_answer() -> String:
	if Net.lag_peer == null:
		return "No connection to slow down: %s." % ("you're hosting" if Net.mode == Net.Mode.HOST else "you're offline")
	var now := _simulated()
	if now == "":
		return "Simulated lag off."
	return "%s, on your connection only. %s off to stop." % ["S" + now.substr(1), SIMULATE]


## The simulated lag and stalls, for reports: "" if none.
static func _simulated() -> String:
	var peer := Net.lag_peer
	if peer == null:
		return ""
	var parts: Array[String] = []
	if peer.lag_ms > 0.0:
		parts.append("+%d ms%s" % [roundi(peer.lag_ms), " ±%d" % roundi(peer.jitter_ms) if peer.jitter_ms > 0.0 else ""])
	if peer.stall_ms > 0.0 and peer.stall_every > 0.0:
		parts.append("%d ms stalls ~%ss" % [roundi(peer.stall_ms), str(snappedf(peer.stall_every, 0.1))])
	return "" if parts.is_empty() else "simulated " + ", ".join(parts)


## The live panel (\diag live): a few short lines. `pings` are the latest
## round trips in ms, `server` the server's latest info.
static func live_text(pings: Array[float], server: Dictionary, me: PlayerShape) -> String:
	var lines: Array[String] = ["%d fps  frame %.1f ms%s" % [
			Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"  " + _worst(worst_frame()) if worst_frame() > 0.0 else ""]]
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
		var hitch := _worst(server.get("worst_frame", 0.0))
		lines.append("server %d fps  physics %.1f/%.1f ms  %d on%s" % [
				server.get("fps", 0), server.get("physics_ms", 0.0),
				1000.0 / maxi(int(server.get("ticks", 60)), 1), server.get("players", 0),
				"  " + hitch if hitch != "" else ""])
	return "\n".join(lines)


## Server only: how the server is keeping up.
static func server_info() -> Dictionary:
	return {
		"version": Net.version,
		"build": BuildInfo.id(),
		"fps": Engine.get_frames_per_second(),
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"ticks": Engine.physics_ticks_per_second,
		"players": Net.players.size(),
		"enemies": Engine.get_main_loop().get_nodes_in_group(Enemy.GROUP).size(),
		"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"uptime": Time.get_ticks_msec() / 1000.0,
		"worst_frame": worst_frame(),
	}


## The write-up. `pings` are round trips in ms, `sent` how many went out,
## `server` the server's info ({} if it never answered), `me` your shape.
static func report(pings: Array[float], sent: int, server: Dictionary, me: PlayerShape) -> String:
	var lines: Array[String] = ["Diagnostics (version %s, build %s, %s)" % [
			Net.version, BuildInfo.describe(BuildInfo.id()), _platform()]]
	var window := DisplayServer.window_get_size()
	lines.append("  You: %d fps (%s), frame %.1f ms, longest frame %s, %s, %dx%d" % [
		Engine.get_frames_per_second(), _cap(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		_longest(worst_frame()), "Low" if Graphics.low else "High", window.x, window.y])
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
		lines.append("  Server: %d fps, physics %.1f ms a step (of %.1f), longest frame %s, %s, %s, %d MB, up %s%s" % [
			server.get("fps", 0), server.get("physics_ms", 0.0), 1000.0 / maxi(int(server.get("ticks", 60)), 1),
			_longest(server.get("worst_frame", 0.0)),
			_count(server.get("players", 0), "player"), _count(server.get("enemies", 0), "enemy", "enemies"),
			roundi(server.get("memory_mb", 0.0)),
			_duration(server.get("uptime", 0.0)),
			"" if server.get("version", "") == Net.version else ", version %s" % server.get("version", "?")])
		lines.append("  Server build: %s%s" % [BuildInfo.describe(str(server.get("build", ""))),
				"" if str(server.get("build", "")) == BuildInfo.id() else " (not the same as yours)"])
	return "\n".join(lines)


## For reports: "40 ms (last 10 s)" or "under 25 ms (last 10 s)".
static func _longest(ms: float) -> String:
	var window := roundi(HITCH_WINDOW)
	if ms <= 0.0:
		return "under %d ms (last %d s)" % [roundi(HITCH_MS), window]
	return "%d ms (last %d s)" % [roundi(ms), window]


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
