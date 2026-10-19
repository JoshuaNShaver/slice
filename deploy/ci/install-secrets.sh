#!/usr/bin/env bash
# Runs on the GitHub runner after ssh-setup.sh. Checks each secret the
# server needs, copies it onto the server (over SSH stdin, never on a
# command line), then checks it again from the server.
#
# - HCLOUD_READ_TOKEN -> /etc/slice/hcloud.env, for the traffic watch.
#   Must be a Read token from the same Hetzner project.
# - SUPABASE_URL, SUPABASE_SECRET_KEY -> /etc/slice/server.env, for the
#   game server. Must be a secret key for SUPABASE_PROJECT_REF's project.
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

# --- SUPABASE_URL, SUPABASE_SECRET_KEY ----------------------------------------
# -> /etc/slice/server.env, read by slice.service (log 0105).
: "${SUPABASE_URL:?missing secret SUPABASE_URL}"
: "${SUPABASE_SECRET_KEY:?missing secret SUPABASE_SECRET_KEY}"
SUPABASE_URL="${SUPABASE_URL%/}"
if [ -n "${SUPABASE_PROJECT_REF:-}" ] && [ "$SUPABASE_URL" != "https://$SUPABASE_PROJECT_REF.supabase.co" ]; then
	echo "::error::SUPABASE_URL should be https://<SUPABASE_PROJECT_REF>.supabase.co; it names a different project."
	exit 1
fi
# Only a secret key may list users through the admin API.
check_supabase='code="$(curl -sS -o /dev/null -w "%{http_code}" -H "apikey: $SUPABASE_SECRET_KEY" "$SUPABASE_URL/auth/v1/admin/users?per_page=1")"; [ "$code" = 200 ] || { echo "Supabase admin API answered HTTP $code (expected 200)"; exit 1; }'
if ! (export SUPABASE_URL SUPABASE_SECRET_KEY; bash -c "$check_supabase"); then
	echo "::error::SUPABASE_SECRET_KEY was refused. Use a secret key (sb_secret_...), not the publishable one."
	exit 1
fi

printf 'SUPABASE_URL=%s\nSUPABASE_SECRET_KEY=%s\n' "$SUPABASE_URL" "$SUPABASE_SECRET_KEY" \
	| ssh root@server 'install -d -m 700 /etc/slice && umask 077 && cat > /etc/slice/server.env'
# Same check again, from the server, with the installed file.
ssh root@server "set -a; . /etc/slice/server.env; set +a; $check_supabase"
echo "SUPABASE_URL and SUPABASE_SECRET_KEY checked and installed."
