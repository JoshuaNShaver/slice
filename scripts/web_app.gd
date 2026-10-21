class_name WebApp
## The web build as an installable app (design log 0122). Godot's service
## worker keeps the game's files for offline starts and serves those first,
## so after a deploy a player can open the old build. When the server turns
## it away for its version, update_to() swaps in the new build and reloads.
## On launch, use_new_build() switches to a build that finished downloading
## in the background, so a deploy reaches players by their next launch even
## without a version change (design log 0127). check_build() goes further:
## if the host serves a different build (BuildInfo, log 0166), it switches
## right away.


## Activates the newest service worker (it fetches the new build), then
## reloads every tab. Reloads anyway after 10 s, whatever happens.
const SWITCH_BUILD := """
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
"""

## use_new_build()'s check, as a function check_build() can fall back on.
const USE_NEW_BUILD := """
		window.godotUseNewBuild = function () {
			if (!('serviceWorker' in navigator)) { return; }
			navigator.serviceWorker.getRegistration().then(function (reg) {
				if (!reg) { return; }
				// Once per tab, so a worker that won't take over can't loop reloads.
				if (reg.waiting && navigator.serviceWorker.controller && !sessionStorage.getItem('slice_new_build')) {
					sessionStorage.setItem('slice_new_build', '1');
					reg.waiting.postMessage('update');  // the worker reloads this page
				} else {
					reg.update();
				}
			}).catch(function () {});
		};
"""

## Web only. If a newer build is downloaded and waiting, switches to it (the
## page reloads); otherwise asks for one, ready for the next launch.
static func use_new_build() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(USE_NEW_BUILD + "godotUseNewBuild();", true)


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
	JavaScriptBridge.eval(SWITCH_BUILD, true)
	return true


## Web only, on launch (log 0166): asks the host which build it serves now
## (build_id.txt, past every cache) and switches to it at once if it isn't
## this one; once per build and tab, so a stuck worker can't loop reloads.
## Without an answer it falls back to use_new_build().
static func check_build() -> void:
	if not OS.has_feature("web"):
		return
	var mine := JSON.stringify(BuildInfo.id())
	JavaScriptBridge.eval(USE_NEW_BUILD + """
		(function () {
			var mine = %s;
			var fallback = function () { godotUseNewBuild(); };
			fetch('%s?t=' + Date.now(), {cache: 'no-store'}).then(function (r) {
				return r.ok ? r.text() : '';
			}).then(function (served) {
				served = served.trim();
				if (!served || !mine || served === mine) { fallback(); return; }
				var key = 'slice_build_' + served;
				if (sessionStorage.getItem(key)) { return; }
				sessionStorage.setItem(key, '1');
				%s
			}).catch(fallback);
		})();
	""" % [mine, BuildInfo.SERVED, SWITCH_BUILD], true)
