class_name LoopbackCatcher
extends RefCounted
## Desktop login (design log 0115): a tiny HTTP listener on 127.0.0.1 that
## catches the browser coming back from Supabase with ?code=... and shows
## a "you can close this tab" page.
##
## The ports are fixed because Supabase only redirects to allowed URLs
## (supabase/config.toml, additional_redirect_urls).

const PORTS: Array[int] = [47613, 47614, 47615]
const CALLBACK_PATH := "/auth/callback"
const PAGE := "<!doctype html><meta charset=utf-8><title>Flatland</title>" \
		+ "<body style=\"font-family:Georgia,serif;background:#efe3c8;color:#3b2f22;text-align:center;padding-top:20vh\">" \
		+ "<h1>%s</h1><p>%s</p></body>"

var port := 0
var _server: TCPServer
var _cancelled := false


## Starts listening; false if every port is taken.
func listen() -> bool:
	for p in PORTS:
		var server := TCPServer.new()
		if server.listen(p, "127.0.0.1") == OK:
			_server = server
			port = p
			return true
	return false


func redirect_url() -> String:
	return "http://127.0.0.1:%d%s" % [port, CALLBACK_PATH]


func cancel() -> void:
	_cancelled = true


## Waits for the browser: {"code": String} or {"error": String}.
func wait_for_code(tree: SceneTree, timeout: float) -> Dictionary:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not _cancelled and Time.get_ticks_msec() < deadline:
		await tree.process_frame
		if not _server.is_connection_available():
			continue
		var result := await _serve(tree, _server.take_connection())
		if not result.is_empty():
			_server.stop()
			return result
	_server.stop()
	return {"error": "Login cancelled." if _cancelled else "Login timed out. Try again."}


## One request. {} if it wasn't the callback (e.g. a favicon request).
func _serve(tree: SceneTree, peer: StreamPeerTCP) -> Dictionary:
	var request := ""
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline and not request.contains("\r\n\r\n"):
		peer.poll()
		var available := peer.get_available_bytes()
		if available > 0:
			request += peer.get_utf8_string(available)
		elif peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
		else:
			await tree.process_frame
	var target := request.get_slice("\r\n", 0).get_slice(" ", 1)  # GET <target> HTTP/1.1
	if not target.begins_with(CALLBACK_PATH):
		_respond(peer, "404 Not Found", "Not here", "")
		return {}
	var query := parse_query(target.get_slice("?", 1) if target.contains("?") else "")
	if query.has("code"):
		_respond(peer, "200 OK", "Logged in", "You can close this tab and go back to the game.")
		return {"code": query.code}
	var why: String = query.get("error_description", query.get("error", "no code came back"))
	_respond(peer, "200 OK", "Login failed", why)
	return {"error": "Login failed: %s" % why}


func _respond(peer: StreamPeerTCP, status: String, title: String, text: String) -> void:
	var body := (PAGE % [title.xml_escape(), text.xml_escape()]).to_utf8_buffer()
	var head := "HTTP/1.1 %s\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" \
			% [status, body.size()]
	peer.put_data(head.to_utf8_buffer() + body)
	peer.disconnect_from_host()


static func parse_query(query: String) -> Dictionary:
	var out := {}
	for pair in query.split("&", false):
		var key := pair.get_slice("=", 0).uri_decode()
		out[key] = pair.get_slice("=", 1).replace("+", " ").uri_decode() if pair.contains("=") else ""
	return out
