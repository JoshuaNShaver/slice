#!/usr/bin/env bash
# Runs on the server, as the slice user, from inside a freshly uploaded
# release (/opt/slice/releases/<commit>). Imports it, exports the web
# client into it (build/web, which Caddy serves; log 0121), points
# /opt/slice/current at it and restarts the server. If the server doesn't
# come up, goes back to the previous release, web client included.
set -euo pipefail

RELEASE="$(cd "$(dirname "$0")/.." && pwd)"
CURRENT=/opt/slice/current
GODOT=/opt/godot/godot
PORT=24680
if [ -f /etc/default/slice ]; then  # written by setup-server.sh
	. /etc/default/slice
	PORT="${SLICE_PORT:-$PORT}"
fi
KEEP=5

# The build id (log 0166): this release's commit, for the server (it has no
# git history here) and the web export.
export SLICE_BUILD="$(basename "$RELEASE" | cut -c1-7)"
printf '%s\n' "$SLICE_BUILD" > "$RELEASE/build_id.txt"

echo "Importing $RELEASE"
timeout 600 "$GODOT" --headless --path "$RELEASE" --import

echo "Exporting the web client"
mkdir -p "$RELEASE/build/web"
timeout 600 "$GODOT" --headless --path "$RELEASE" --export-release "Web" "$RELEASE/build/web/index.html" \
	> "$RELEASE/build/web-export.log" 2>&1 || true
if [ ! -s "$RELEASE/build/web/index.wasm" ] || [ ! -s "$RELEASE/build/web/index.pck" ]; then
	tail -n 30 "$RELEASE/build/web-export.log"
	echo "Web export failed. If the export template is missing, run 001-full-deploy."
	exit 1
fi

PREVIOUS="$(readlink -e "$CURRENT" || true)"  # empty on the first deploy

switch_to() {
	ln -sfn "$1" "$CURRENT.new"
	mv -T "$CURRENT.new" "$CURRENT"
	sudo /usr/bin/systemctl restart slice
}

listening() {
	for _ in $(seq 1 30); do
		if ss -Htln "sport = :$PORT" | grep -q .; then  # TCP: WebSocket
			return 0
		fi
		sleep 1
	done
	return 1
}

switch_to "$RELEASE"
if listening; then
	echo "Server is up on TCP $PORT running $(basename "$RELEASE")"
else
	echo "Server didn't start. Recent log:"
	journalctl -u slice -n 40 --no-pager || true
	if [ -n "$PREVIOUS" ] && [ "$PREVIOUS" != "$RELEASE" ]; then
		echo "Going back to $(basename "$PREVIOUS")"
		switch_to "$PREVIOUS"
	fi
	exit 1
fi

# Keep the newest few releases, never the one running.
ls -1dt /opt/slice/releases/*/ | tail -n +$((KEEP + 1)) | while read -r old; do
	[ "$(readlink -f "$old")" = "$RELEASE" ] || rm -rf "$old"
done
