#!/usr/bin/env bash
# Configures an Ubuntu 24.04 VPS (Hetzner, x86 or ARM) as the game server.
# Run as root by the 001-full-deploy workflow (see deploy/README.md):
#   ssh root@server "bash -s -- '<deploy public key>' '<domain>' '<port>'" < deploy/setup-server.sh
# Arguments: the public half of the key GitHub Actions deploys with; the
# domain players join (wss:// through Caddy, design log 0118), or "" for
# plain ws:// on the game port; the game server's port (default 24680).
# Safe to run again. Secrets are installed separately (deploy/ci/install-secrets.sh).
set -euo pipefail

DEPLOY_PUBKEY="${1:?usage: setup-server.sh \"<deploy public key>\" [domain] [port]}"
DOMAIN="${2:-}"
PORT="${3:-24680}"
GODOT_VERSION="4.5.1"
[[ "$PORT" =~ ^[0-9]+$ ]] || { echo "Bad port: $PORT"; exit 1; }
[[ -z "$DOMAIN" || "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || { echo "Bad domain: $DOMAIN"; exit 1; }

# A new server may still be finishing first boot (and holding the apt lock).
command -v cloud-init >/dev/null && cloud-init status --wait >/dev/null || true

apt-get update -q
apt-get install -y -q unzip curl jq ufw libfontconfig1  # fontconfig: quiets Godot's font errors
[ -z "$DOMAIN" ] || apt-get install -y -q caddy

# --- Godot (headless use of the normal Linux build) -------------------------
case "$(uname -m)" in
	x86_64) GODOT_ARCH="x86_64" ;;
	aarch64) GODOT_ARCH="arm64" ;;
	*) echo "Unsupported CPU: $(uname -m)"; exit 1 ;;
esac
GODOT_NAME="Godot_v${GODOT_VERSION}-stable_linux.${GODOT_ARCH}"
if [ ! -x /opt/godot/godot ] || ! /opt/godot/godot --version | grep -q "^${GODOT_VERSION}.stable"; then
	TMP="$(mktemp -d)"
	BASE="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"
	curl -fsSL -o "$TMP/$GODOT_NAME.zip" "$BASE/$GODOT_NAME.zip"
	curl -fsSL -o "$TMP/SHA512-SUMS.txt" "$BASE/SHA512-SUMS.txt"
	(cd "$TMP" && grep " $GODOT_NAME.zip\$" SHA512-SUMS.txt | sha512sum -c -)
	mkdir -p /opt/godot
	unzip -o -q "$TMP/$GODOT_NAME.zip" -d "$TMP"
	install -m 755 "$TMP/$GODOT_NAME" /opt/godot/godot
	rm -rf "$TMP"
fi

# --- The slice user: runs the server and receives deploys -------------------
id slice >/dev/null 2>&1 || useradd --create-home --shell /bin/bash slice
usermod -aG systemd-journal slice  # deploys show the server log on failure
install -d -o slice -g slice -m 700 /home/slice/.ssh
echo "$DEPLOY_PUBKEY" > /home/slice/.ssh/authorized_keys
chown slice:slice /home/slice/.ssh/authorized_keys
chmod 600 /home/slice/.ssh/authorized_keys
install -d -o slice -g slice /opt/slice /opt/slice/releases
# The port, for deploys to check (activate-release.sh).
echo "SLICE_PORT=${PORT}" > /etc/default/slice
chmod 644 /etc/default/slice

# Deploys may restart the game server, nothing else.
cat > /etc/sudoers.d/slice <<'EOF'
slice ALL=(root) NOPASSWD: /usr/bin/systemctl restart slice
EOF
chmod 440 /etc/sudoers.d/slice
visudo -cf /etc/sudoers.d/slice

# --- Game server service ----------------------------------------------------
cat > /etc/systemd/system/slice.service <<EOF
[Unit]
Description=Slice dedicated game server
After=network-online.target
Wants=network-online.target

[Service]
User=slice
# Supabase URL and key, installed by 001-full-deploy (deploy/ci/install-secrets.sh).
EnvironmentFile=-/etc/slice/server.env
WorkingDirectory=/opt/slice/current
ExecStart=/opt/godot/godot --headless --path /opt/slice/current -- --server --port=${PORT} --no-hot-reload
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# --- Traffic watch: stops the server near the plan's traffic allowance ------
cat > /usr/local/bin/slice-traffic-watch <<'EOF'
#!/usr/bin/env bash
# Stops the game server when outgoing traffic passes LIMIT_PERCENT of the
# server's included traffic. Needs a read-only Hetzner API token in
# /etc/slice/hcloud.env as HCLOUD_TOKEN=...; does nothing without one.
set -euo pipefail
[ -f /etc/slice/hcloud.env ] || exit 0
. /etc/slice/hcloud.env
LIMIT_PERCENT="${LIMIT_PERCENT:-80}"
ID="$(curl -fsS http://169.254.169.254/hetzner/v1/metadata/instance-id)"
read -r OUT INCLUDED < <(curl -fsS -H "Authorization: Bearer $HCLOUD_TOKEN" \
	"https://api.hetzner.cloud/v1/servers/$ID" \
	| jq -r '.server | "\(.outgoing_traffic // 0) \(.included_traffic // 0)"')
[ "$INCLUDED" -gt 0 ] 2>/dev/null || exit 0
USED=$(( OUT * 100 / INCLUDED ))
if [ "$USED" -ge "$LIMIT_PERCENT" ]; then
	echo "Outgoing traffic at ${USED}% of the allowance; stopping the game server."
	systemctl stop slice
fi
EOF
chmod 755 /usr/local/bin/slice-traffic-watch

cat > /etc/systemd/system/slice-traffic-watch.service <<'EOF'
[Unit]
Description=Stop the game server near the traffic allowance

[Service]
Type=oneshot
ExecStart=/usr/local/bin/slice-traffic-watch
EOF

cat > /etc/systemd/system/slice-traffic-watch.timer <<'EOF'
[Unit]
Description=Check traffic every 15 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=15min

[Install]
WantedBy=timers.target
EOF
install -d -m 700 /etc/slice

systemctl daemon-reload
systemctl enable slice.service slice-traffic-watch.timer
systemctl start slice-traffic-watch.timer
# slice.service starts on the first deploy (there's no /opt/slice/current yet).

# --- Firewall ---------------------------------------------------------------
ufw allow OpenSSH
ufw delete allow "${PORT}/udp" >/dev/null 2>&1 || true  # ENet, before log 0110
if [ -n "$DOMAIN" ]; then
	# Players come in through Caddy only, so logins never cross the
	# internet unencrypted (design log 0118). 80: certificates, redirects.
	ufw allow 80/tcp
	ufw allow 443/tcp
	ufw delete allow "${PORT}/tcp" >/dev/null 2>&1 || true
else
	ufw allow "${PORT}/tcp"  # plain ws://
fi
ufw --force enable

# --- Caddy: wss:// on 443 with a Let's Encrypt certificate (log 0118) -------
if [ -n "$DOMAIN" ]; then
	cat > /etc/caddy/Caddyfile <<CADDY
# Written by deploy/setup-server.sh. Passes WebSocket through to the game.
${DOMAIN} {
	reverse_proxy 127.0.0.1:${PORT}
}
CADDY
	caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
	systemctl enable caddy
	systemctl reload-or-restart caddy
	echo "Caddy serving wss://${DOMAIN} -> 127.0.0.1:${PORT}"
else
	systemctl disable --now caddy >/dev/null 2>&1 || true
fi

echo "Server configured. Godot: $(/opt/godot/godot --version)"
