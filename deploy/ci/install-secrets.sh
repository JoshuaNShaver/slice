#!/usr/bin/env bash
# Runs on the GitHub runner after ssh-setup.sh. Checks each secret the
# server needs, copies it onto the server (over SSH stdin, never on a
# command line), then checks it again from the server.
#
# - HCLOUD_READ_TOKEN -> /etc/slice/hcloud.env, for the traffic watch.
#   Must be a Read token from the same Hetzner project.
set -euo pipefail
: "${HCLOUD_READ_TOKEN:?missing secret HCLOUD_READ_TOKEN}"
NAME="${SERVER_NAME:-slice-server}"
API=https://api.hetzner.cloud/v1

# --- HCLOUD_READ_TOKEN --------------------------------------------------------
seen="$(curl -sS --fail-with-body -H "Authorization: Bearer $HCLOUD_READ_TOKEN" \
	"$API/servers?name=$NAME" | jq '.servers | length')"
if [ "$seen" != "1" ]; then
	echo "::error::HCLOUD_READ_TOKEN can't see $NAME. Is it from the same Hetzner project?"
	exit 1
fi
# A read-only token is refused (403) on any write. An empty body means a
# write token gets a validation error instead and nothing is created.
code="$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
	-H "Authorization: Bearer $HCLOUD_READ_TOKEN" -H "Content-Type: application/json" \
	-d '{}' "$API/ssh_keys")"
if [ "$code" != "403" ]; then
	echo "::error::HCLOUD_READ_TOKEN can write (got HTTP $code, expected 403). Use a Read-only token."
	exit 1
fi

printf 'HCLOUD_TOKEN=%s\n' "$HCLOUD_READ_TOKEN" \
	| ssh root@server 'install -d -m 700 /etc/slice && umask 077 && cat > /etc/slice/hcloud.env'
# The traffic watch fails if the token doesn't work from the server.
ssh root@server 'systemctl start slice-traffic-watch.service'
echo "HCLOUD_READ_TOKEN checked and installed."
