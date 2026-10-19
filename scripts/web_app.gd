class_name WebApp
## The web build as an installable app (design log 0122). Godot's service
## worker keeps the game's files for offline starts and serves those first,
## so after a deploy a player can open the old build. When the server turns
## it away for its version, update_to() swaps in the new build and reloads.


## The server's version from its "please update" message, or "" if the
## message is about something else. That message comes from Handshake,
## whose wording old servers keep.
static func version_in_rejection(reason: String) -> String:
	var found := RegEx.create_from_string("^This server runs version ([^;]+);").search(reason)
	return found.get_string(1) if found != null else ""


## Web only. Activates the newest service worker (it fetches the new
## build) and reloads. At most once per server version and browser tab,
## so a server running an older build than this page can't loop reloads.
## False if it already tried for this version.
static func update_to(server_version: String) -> bool:
	if not OS.has_feature("web"):
		return false
	var key := JSON.stringify("slice_update_" + server_version)
	if str(JavaScriptBridge.eval("sessionStorage.getItem(%s) || ''" % key, true)) != "":
		return false
	JavaScriptBridge.eval("sessionStorage.setItem(%s, '1')" % key, true)
	JavaScriptBridge.eval("""
		(function () {
			var reload = function () { window.location.reload(); };
			if (!('serviceWorker' in navigator)) { reload(); return; }
			setTimeout(reload, 10000);  // whatever happens below
			navigator.serviceWorker.getRegistration().then(function (reg) {
				if (!reg) { reload(); return; }
				return reg.update().then(function () {
					var worker = reg.waiting || reg.installing;
					if (!worker) { reload(); return; }
					// The worker's 'update' message: take over and reload every tab.
					var go = function () {
						if (worker.state === 'installed') { worker.postMessage('update'); }
						else if (worker.state === 'activated' || worker.state === 'redundant') { reload(); }
					};
					worker.addEventListener('statechange', go);
					go();
				});
			}).catch(reload);
		})();
	""", true)
	return true
