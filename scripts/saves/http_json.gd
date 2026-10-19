class_name HttpJson
extends RefCounted
## One JSON request over HTTP(S), awaited without blocking the game loop
## (an HTTPRequest node polled each frame). Used for Supabase by the
## server (SupabaseStore, login checks) and by clients (SupabaseAuth).

const TIMEOUT := 15.0  # s


## {"ok": bool (a 2xx reply), "code": HTTP status (0 if none),
## "data": the parsed JSON body or null, "error": "" or what went wrong}.
static func request(parent: Node, method: HTTPClient.Method, url: String,
		headers: PackedStringArray, body: Variant = null) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	parent.add_child(http)
	var sent_headers := PackedStringArray(headers)
	var text := ""
	if body != null:
		text = JSON.stringify(body)
		sent_headers.append("Content-Type: application/json")
	var err := http.request(url, sent_headers, method, text)
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "data": null, "error": "couldn't send (%s)" % error_string(err)}
	var result: Array = await http.request_completed
	http.queue_free()
	var status: int = result[0]
	var code: int = result[1]
	var raw: String = (result[3] as PackedByteArray).get_string_from_utf8()
	var json := JSON.new()  # quietly: a body may be HTML
	var data: Variant = json.data if raw.strip_edges() != "" and json.parse(raw) == OK else null
	if status != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": 0, "data": null, "error": "no reply (%s)" % _result_name(status)}
	var ok := code >= 200 and code < 300
	var error := ""
	if not ok:
		error = "HTTP %d" % code
		if data is Dictionary:
			for k: String in ["msg", "message", "error_description", "error"]:
				if data.get(k) is String:
					error += ": " + data[k]
					break
	return {"ok": ok, "code": code, "data": data, "error": error}


static func _result_name(status: int) -> String:
	match status:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "can't connect"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "can't resolve host"
		HTTPRequest.RESULT_TIMEOUT:
			return "timed out"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS handshake failed"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "connection error"
	return "result %d" % status
