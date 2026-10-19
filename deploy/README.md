# Deploying the server

The dedicated server runs on a Hetzner VPS (Ubuntu 24.04, x86 or ARM) from
source: the server has a plain Godot 4.5.1 binary, and each deploy uploads
the committed project and imports it there. No export templates needed.

On the server:
- `/opt/godot/godot`: Godot.
- `/opt/slice/releases/<commit>/`: the last 5 deploys. `/opt/slice/current`
  points at the running one.
- `slice.service`: the game server, UDP 24680. Logs: `journalctl -u slice -f`.
- `slice-traffic-watch.timer`: stops the server at 80% of the traffic
  allowance (once a token is added, see step 4).

## One-time setup

1. **Create the server** in the Hetzner console: Ubuntu 24.04, add your own
   SSH key.
2. **Make a deploy key** (no passphrase) on your machine:
   ```
   ssh-keygen -t ed25519 -N "" -C slice-deploy -f ~/.ssh/slice_deploy
   ```
3. **Run the setup script** (from the repo root):
   ```
   ssh root@SERVER_IP "bash -s -- '$(cat ~/.ssh/slice_deploy.pub)'" < deploy/setup-server.sh
   ```
4. **Traffic watch (optional, recommended):** in the Hetzner console make a
   **Read** API token, then:
   ```
   ssh root@SERVER_IP 'umask 077; echo "HCLOUD_TOKEN=<token>" > /etc/slice/hcloud.env'
   ```
5. **GitHub secrets** (repo → Settings → Secrets and variables → Actions):
   - `DEPLOY_HOST`: the server's IP.
   - `DEPLOY_SSH_KEY`: contents of `~/.ssh/slice_deploy` (the private key).
   - `DEPLOY_KNOWN_HOSTS`: output of `ssh-keyscan SERVER_IP`.

## Deploying

GitHub → Actions → **Deploy server** → Run workflow, and pick the branch.
It deploys the latest commit on that branch (uncommitted or unpushed work
isn't included). If the new build doesn't start, the server goes back to the
previous one and the workflow fails with the log.

Players join at `SERVER_IP` port 24680. When WebSocket support lands (log
0099), the setup gains Caddy and ports 80/443 for `wss://`.
