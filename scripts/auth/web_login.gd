class_name WebLogin
extends RefCounted
## Web build login (design log 0115): the page itself goes to Supabase and
## comes back with ?code=... . What the page needs after coming back (the
## PKCE verifier, project URL and key) waits in localStorage meanwhile.
##
## The page is the game server's own site, not in a frame (design log
## 0121), and its addresses are in Supabase's redirect list
## (supabase/config.toml). TODO(log 0115): untested end to end, notably
## from an installed app on iOS.

const STORAGE_KEY := "slice_login"


## This page's address without its query, to come back to.
static func page_url() -> String:
	return str(JavaScriptBridge.eval("window.location.origin + window.location.pathname", true))


static func start(authorize: String, verifier: String, url: String, key: String) -> void:
	var saved := JSON.stringify({"verifier": verifier, "url": url, "key": key})
	JavaScriptBridge.eval("localStorage.setItem(%s, %s)" % [JSON.stringify(STORAGE_KEY), JSON.stringify(saved)], true)
	JavaScriptBridge.eval("window.location.href = %s" % JSON.stringify(authorize), true)


## After coming back: {"code", "verifier", "url", "key"}, {"error"}, or {}
## if this page load isn't a return from logging in. Clears the query.
static func take_result() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var query := str(JavaScriptBridge.eval("window.location.search", true)).trim_prefix("?")
	var params := LoopbackCatcher.parse_query(query)
	if not params.has("code") and not params.has("error"):
		return {}
	JavaScriptBridge.eval("history.replaceState(null, '', window.location.pathname)", true)
	var raw := str(JavaScriptBridge.eval("localStorage.getItem(%s) || ''" % JSON.stringify(STORAGE_KEY), true))
	JavaScriptBridge.eval("localStorage.removeItem(%s)" % JSON.stringify(STORAGE_KEY), true)
	var saved: Variant = JSON.parse_string(raw) if raw != "" else null
	if params.has("error"):
		return {"error": "Login failed: %s" % params.get("error_description", "unknown error")}
	if not saved is Dictionary:
		return {}  # this page reloaded with an old address; that login was finished
	return {"code": params.code, "verifier": saved.verifier, "url": saved.url, "key": saved.key}
