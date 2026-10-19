# Deploying the server

GitHub Actions manage the game server end to end. Every key lives as a
GitHub secret; nothing is copied by hand.

- **Provision server** (manual): creates the Hetzner server if you tick
  *Create the server*, configures it (`setup-server.sh`), checks and
  installs its secrets (`ci/install-secrets.sh`), then deploys. Safe to
  run again, e.g. after changing a secret or the setup script.
- **Deploy server** (manual): first applies Supabase changes
  (`supabase/migrations/`, then the auth settings in `supabase/config.toml`;
  the log shows what will change before it's applied). Then uploads the
  committed source of the chosen branch, imports it on the server, restarts
  it, and goes back to the previous build if the new one doesn't start.

The server runs the project from source with a plain Godot 4.5.1 binary,
so no export templates are needed.

## One-time setup

1. **Hetzner API tokens** (Console → your project → Security → API tokens):
   one **Read & Write** and one **Read**.
2. **Two SSH keys** on your machine, no passphrase:
   ```
   ssh-keygen -t ed25519 -N "" -C slice-deploy -f slice_deploy
   ssh-keygen -t ed25519 -N "" -C slice-host -f slice_host
   ```
   `slice_deploy` is how GitHub logs in. `slice_host` becomes the server's
   own SSH identity, so GitHub can verify it's talking to the real server.
3. **GitHub secrets** (repo → Settings → Secrets and variables → Actions):

   | Secret | Value |
   |---|---|
   | `HCLOUD_TOKEN` | the Read & Write token (creates and finds the server) |
   | `HCLOUD_READ_TOKEN` | the Read token (goes on the server, for the traffic watch) |
   | `DEPLOY_SSH_KEY` | contents of `slice_deploy` (private key) |
   | `DEPLOY_HOST_KEY` | contents of `slice_host` (private key) |
   | `SUPABASE_ACCESS_TOKEN` | Supabase → Account → Access Tokens (GitHub only) |
   | `SUPABASE_PROJECT_REF` | the ID in the project's dashboard URL |
   | `SUPABASE_DB_PASSWORD` | the project's database password (GitHub only) |
   | `SUPABASE_URL` | `https://<project-ref>.supabase.co` (goes on the server) |
   | `SUPABASE_SECRET_KEY` | Project Settings → API Keys → secret key (goes on the server) |
   | `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID` | Google Cloud OAuth client ID |
   | `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET` | Google Cloud OAuth client secret |

   Then delete the four key files from your machine.
4. **Variables (optional)**, same page, Variables tab:
   `SERVER_TYPE` (default `cax11`, ARM, EU only), `SERVER_LOCATION`
   (default `nbg1`), `SERVER_NAME` (default `slice-server`). For the US use
   an x86 type such as `cpx11` and `ash` or `hil`. Check current type names
   in the Hetzner console; the workflow shows the API's error if one is wrong.
5. Push, then run **Provision server** with *Create the server* ticked.

## On the server

- `/opt/godot/godot`: Godot.
- `/opt/slice/releases/<commit>/`: the last 5 deploys; `/opt/slice/current`
  points at the running one.
- `slice.service`: the game server, UDP 24680. Logs: `journalctl -u slice -f`.
- `slice-traffic-watch.timer`: every 15 min, stops the server at 80% of the
  traffic allowance.
- `/etc/slice/`: secrets installed by Provision server (root only):
  `hcloud.env` for the traffic watch, `server.env` (Supabase URL and secret
  key) passed to the game server as environment variables.

To log in yourself, add your own key in the Hetzner console before creating
the server, or use `slice_deploy` before deleting it.

## Notes

- Changing `DEPLOY_HOST_KEY` only applies to a newly created server.
- Players join at the server's IP, port 24680. When WebSocket support lands
  (log 0099), setup gains Caddy and ports 80/443 for `wss://`.
- New server secrets get a check and an install step in
  `ci/install-secrets.sh`.
- Migrations must work with the server version still running (log 0105):
  add a column in one deploy, drop the old one in a later deploy.
