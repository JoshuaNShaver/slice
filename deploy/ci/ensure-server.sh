#!/usr/bin/env bash
# Runs on the GitHub runner. Makes sure the Hetzner server exists, and
# creates it only when CREATE=true (it costs money). A new server gets the
# deploy key for root and the pinned SSH host key (DEPLOY_HOST_KEY), so we
# never trust a host key on first sight.
set -euo pipefail
: "${HCLOUD_TOKEN:?missing secret HCLOUD_TOKEN}"
: "${DEPLOY_SSH_KEY:?missing secret DEPLOY_SSH_KEY}"
: "${DEPLOY_HOST_KEY:?missing secret DEPLOY_HOST_KEY}"
NAME="${SERVER_NAME:-slice-server}"
TYPE="${SERVER_TYPE:-cax11}"
LOCATION="${SERVER_LOCATION:-nbg1}"
API=https://api.hetzner.cloud/v1

api() {
	curl -sS --fail-with-body -H "Authorization: Bearer $HCLOUD_TOKEN" \
		-H "Content-Type: application/json" "$@"
}

if [ "$(api "$API/servers?name=$NAME" | jq '.servers | length')" -gt 0 ]; then
	echo "Server $NAME exists."
	exit 0
fi
if [ "${CREATE:-false}" != "true" ]; then
	echo "::error::No server named $NAME. Run Provision server again with 'Create the server' ticked."
	exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
printf '%s\n' "$DEPLOY_SSH_KEY" > "$tmp/deploy"
printf '%s\n' "$DEPLOY_HOST_KEY" > "$tmp/host"
chmod 600 "$tmp/deploy" "$tmp/host"
DEPLOY_PUB="$(ssh-keygen -y -f "$tmp/deploy" | awk '{print $1" "$2}')"
HOST_PUB="$(ssh-keygen -y -f "$tmp/host" | awk '{print $1" "$2}')"

# Register the deploy key with Hetzner (replacing it if the secret changed).
KEY_NAME="$NAME-deploy"
key_json="$(api "$API/ssh_keys?name=$KEY_NAME")"
key_id="$(jq -r '.ssh_keys[0].id // empty' <<<"$key_json")"
key_pub="$(jq -r '.ssh_keys[0].public_key // empty' <<<"$key_json" | awk '{print $1" "$2}')"
if [ -n "$key_id" ] && [ "$key_pub" != "$DEPLOY_PUB" ]; then
	api -X DELETE "$API/ssh_keys/$key_id" >/dev/null
	key_id=""
fi
if [ -z "$key_id" ]; then
	api -X POST "$API/ssh_keys" \
		-d "$(jq -n --arg n "$KEY_NAME" --arg k "$DEPLOY_PUB" '{name: $n, public_key: $k}')" >/dev/null
fi

# First boot installs our host key instead of generating new ones.
user_data="$(cat <<EOF
#cloud-config
ssh_deletekeys: true
ssh_genkeytypes: []
ssh_keys:
  ed25519_private: |
$(sed 's/^/    /' "$tmp/host")
  ed25519_public: $HOST_PUB
EOF
)"

api -X POST "$API/servers" -d "$(jq -n \
	--arg name "$NAME" --arg type "$TYPE" --arg loc "$LOCATION" \
	--arg key "$KEY_NAME" --arg ud "$user_data" \
	'{name: $name, server_type: $type, location: $loc, image: "ubuntu-24.04",
	  ssh_keys: [$key], user_data: $ud, labels: {app: "slice"}}')" \
	| jq -r '"Created \(.server.name): \(.server.server_type.name) in \(.server.datacenter.location.name), \(.server.public_net.ipv4.ip)"'
