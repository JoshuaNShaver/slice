class_name SupabaseAuth
extends Node
## Client: logging in with Google through Supabase Auth (design logs 0098,
## 0115), using PKCE. The server sends the project's URL and publishable
## key after the handshake (Accounts); this node gets an access token for
## the server to check.
##
## Desktop: opens the system browser and catches the redirect on
## 127.0.0.1 (LoopbackCatcher). Web: sends the page to Supabase and reads
## the code when the page loads again (WebLogin). The session (refresh
## token) is kept in user://account/, so players needn't log in each time;
## on the web in localStorage instead, which saves at once: user:// there
## saves a moment later, and a reload (the update to a new build right
## after logging in) could lose it.

const LOGIN_TIMEOUT := 300.0  # s to finish logging in in the browser
const REFRESH_MARGIN := 120  # s before expiry to refresh
const WEB_SESSION_KEY := "slice_session"  # localStorage, web only

var url := ""
var key := ""
var session_path := "user://account/session.json"
## Opens a URL in the browser (tests fetch it instead).
var open_browser := func(address: String) -> void: OS.shell_open(address)
var _catcher: LoopbackCatcher


func configure(supabase_url: String, publishable_key: String) -> void:
	url = supabase_url.trim_suffix("/")
	key = publishable_key


## The email of the saved session for this project, or "".
func saved_email() -> String:
	return str(_load_session().get("email", ""))


## A valid access token from the saved session, refreshed if it's about to
## expire; "" if there's none or it can't be refreshed.
func access_token() -> String:
	var session := _load_session()
	if session.is_empty():
		return ""
	if int(session.get("expires_at", 0)) - REFRESH_MARGIN > int(Time.get_unix_time_from_system()):
		return session.access_token
	var reply := await _token("refresh_token", {"refresh_token": session.get("refresh_token", "")})
	if not reply.ok:
		if reply.code >= 400 and reply.code < 500:
			forget()  # the refresh token is spent or revoked
		return ""
	return _save_session(reply.data)


## Logs in through the browser: {"token": String} or {"error": String}.
## On the web the page leaves for Supabase and this never returns.
func log_in() -> Dictionary:
	var pair := pkce_pair()
	if OS.has_feature("web"):
		WebLogin.start(authorize_url(WebLogin.page_url(), pair.challenge), pair.verifier, url, key)
		return {"error": "Opening the login page…"}
	_catcher = LoopbackCatcher.new()
	if not _catcher.listen():
		return {"error": "Couldn't listen for the login (ports %s busy)." % str(LoopbackCatcher.PORTS)}
	open_browser.call(authorize_url(_catcher.redirect_url(), pair.challenge))
	var caught := await _catcher.wait_for_code(get_tree(), LOGIN_TIMEOUT)
	_catcher = null
	if caught.has("error"):
		return caught
	return await exchange(caught.code, pair.verifier)


func cancel() -> void:
	if _catcher != null:
		_catcher.cancel()


## Web: if the page came back from Supabase with a code, finish logging in.
## {} if there was nothing to finish.
func finish_web_login() -> Dictionary:
	var back := WebLogin.take_result()
	if back.is_empty() or back.has("error"):
		return back
	configure(back.url, back.key)
	return await exchange(back.code, back.verifier)


## PKCE code -> session. {"token": String} or {"error": String}.
func exchange(code: String, verifier: String) -> Dictionary:
	var reply := await _token("pkce", {"auth_code": code, "code_verifier": verifier})
	if not reply.ok:
		return {"error": "Login failed (%s)." % reply.error}
	return {"token": _save_session(reply.data)}


func authorize_url(redirect: String, challenge: String) -> String:
	return "%s/auth/v1/authorize?provider=google&redirect_to=%s&code_challenge=%s&code_challenge_method=s256" \
			% [url, redirect.uri_encode(), challenge]


func forget() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("localStorage.removeItem(%s)" % JSON.stringify(WEB_SESSION_KEY), true)
	if FileAccess.file_exists(session_path):
		DirAccess.remove_absolute(session_path)


## {"verifier", "challenge"}: a random secret and its SHA-256, base64url.
static func pkce_pair() -> Dictionary:
	var verifier := _base64url(Crypto.new().generate_random_bytes(32))
	return {"verifier": verifier, "challenge": _base64url(verifier.sha256_buffer())}


static func _base64url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")


func _token(grant: String, body: Dictionary) -> Dictionary:
	return await HttpJson.request(self, HTTPClient.METHOD_POST,
			"%s/auth/v1/token?grant_type=%s" % [url, grant], ["apikey: " + key], body)


## Keeps a token reply; returns its access token.
func _save_session(data: Variant) -> String:
	if not (data is Dictionary and data.get("access_token") is String):
		return ""
	var user: Variant = data.get("user", {})
	var session := {
		"url": url,
		"access_token": data.access_token,
		"refresh_token": str(data.get("refresh_token", "")),
		"expires_at": int(Time.get_unix_time_from_system()) + int(data.get("expires_in", 3600)),
		"email": str(user.get("email", "")) if user is Dictionary else "",
	}
	if OS.has_feature("web"):
		JavaScriptBridge.eval("localStorage.setItem(%s, %s)" % [JSON.stringify(WEB_SESSION_KEY),
				JSON.stringify(JSON.stringify(session))], true)
		return data.access_token
	DirAccess.make_dir_recursive_absolute(session_path.get_base_dir())
	var file := FileAccess.open(session_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(session))
	return data.access_token


## The saved session, if it's for this project.
func _load_session() -> Dictionary:
	var raw := ""
	if OS.has_feature("web"):
		raw = str(JavaScriptBridge.eval("localStorage.getItem(%s) || ''" % JSON.stringify(WEB_SESSION_KEY), true))
	elif FileAccess.file_exists(session_path):
		raw = FileAccess.get_file_as_string(session_path)
	var data: Variant = JSON.parse_string(raw) if raw != "" else null
	if data is Dictionary and data.get("url") == url and data.get("access_token") is String:
		return data
	return {}
