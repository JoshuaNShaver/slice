extends RefCounted
## Desktop login against tools/tests/supabase_mock.py, run by
## test_auth.gd: PKCE, the loopback listener, the code exchange, the saved
## session and its refresh (design log 0115). Instead of a browser, the
## authorize URL is fetched here; the mock redirects at once to the
## loopback, as Supabase does after Google says yes.

var tree: SceneTree
var _fails := 0


func run() -> int:
	var pair := SupabaseAuth.pkce_pair()
	_check(pair.verifier.length() >= 43 and not pair.challenge.contains("="), "PKCE pair is base64url")

	var auth := SupabaseAuth.new()
	tree.root.add_child(auth)
	auth.session_path = "user://test-auth-%d/session.json" % Time.get_ticks_usec()
	auth.configure(OS.get_environment("SUPABASE_URL"), "sb_publishable_test")
	auth.open_browser = func(address: String) -> void:
		HttpJson.request(auth, HTTPClient.METHOD_GET, address, [])  # follows the redirect
	_check(await auth.access_token() == "", "no session yet")

	var result := await auth.log_in()
	_check(result.get("token") == "good-token-1", "logged in through the loopback: %s" % str(result))
	_check(auth.saved_email() == "one@example.com", "session saved")
	_check(await auth.access_token() == "good-token-1", "saved session reused")

	# An expiring session is refreshed with its refresh token.
	var session: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(auth.session_path))
	var old_refresh: String = session.refresh_token
	session.expires_at = 0
	var file := FileAccess.open(auth.session_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(session))
	file.close()
	_check(await auth.access_token() == "good-token-1", "expired session refreshed")
	session = JSON.parse_string(FileAccess.get_file_as_string(auth.session_path))
	_check(session.refresh_token != old_refresh and session.expires_at > 0, "new refresh token kept")

	# A spent refresh token: the session is forgotten.
	session.expires_at = 0
	session.refresh_token = "spent"
	file = FileAccess.open(auth.session_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(session))
	file.close()
	_check(await auth.access_token() == "", "spent refresh token refused")
	_check(not FileAccess.file_exists(auth.session_path), "bad session forgotten")

	# A wrong verifier is refused.
	var bad := await auth.exchange("no-such-code", "verifier")
	_check(bad.has("error"), "bad code refused: %s" % bad.get("error", ""))

	DirAccess.remove_absolute(auth.session_path.get_base_dir())
	auth.queue_free()
	print("DONE fails=%d" % _fails)
	return _fails


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("%s %s" % ["ok" if ok else "FAIL", what])
