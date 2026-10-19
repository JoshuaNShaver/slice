#!/usr/bin/env bash
# Runs on the GitHub runner. Looks up the server's IP by name and sets up
# SSH to it as host "server", trusting only the pinned host key.
# Then: ssh root@server ... / ssh slice@server ...
set -euo pipefail
: "${HCLOUD_TOKEN:?missing secret HCLOUD_TOKEN}"
: "${DEPLOY_SSH_KEY:?missing secret DEPLOY_SSH_KEY}"
: "${DEPLOY_HOST_KEY:?missing secret DEPLOY_HOST_KEY}"
NAME="${SERVER_NAME:-slice-server}"

IP="$(curl -sS --fail-with-body -H "Authorization: Bearer $HCLOUD_TOKEN" \
	"https://api.hetzner.cloud/v1/servers?name=$NAME" \
	| jq -r '.servers[0].public_net.ipv4.ip // empty')"
if [ -z "$IP" ]; then
	echo "::error::No server named $NAME. Run the Provision server workflow."
	exit 1
fi

install -d -m 700 ~/.ssh
printf '%s\n' "$DEPLOY_SSH_KEY" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519

host_key="$(mktemp)"
printf '%s\n' "$DEPLOY_HOST_KEY" > "$host_key"
chmod 600 "$host_key"
echo "$IP $(ssh-keygen -y -f "$host_key" | awk '{print $1" "$2}')" > ~/.ssh/known_hosts
rm -f "$host_key"

cat > ~/.ssh/config <<EOF
Host server
	HostName $IP
	IdentityFile ~/.ssh/id_ed25519
	IdentitiesOnly yes
	StrictHostKeyChecking yes
	ConnectTimeout 10
EOF

echo "DEPLOY_PUBKEY=$(ssh-keygen -y -f ~/.ssh/id_ed25519 | awk '{print $1" "$2}')" >> "$GITHUB_ENV"
echo "Server $NAME is at $IP"
