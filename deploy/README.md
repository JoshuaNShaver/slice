# Deploying the server

GitHub Actions manage the game server end to end. Every key lives as a
GitHub secret; nothing is copied by hand.

- **001-full-deploy** (manual): creates the Hetzner server if you tick
  *Create the server*, configures it (`setup-server.sh`), checks and
  installs its secrets (`ci/install-secrets.sh`), then deploys. Safe to
  run again, e.g. after changing a secret or the setup script.
- **002-deploy-code** (manual): first applies Supabase changes
  (`supabase/migrations/`, then the auth settings in `supabase/config.toml`;
  the log shows what will change before it's applied). Then uploads the
  committed source of the chosen branch, imports it on the server, exports
  the web client from it, restarts the server, and goes back to the
  previous build (web client included) if the new one doesn't start.

The server runs the project from source with a plain Godot 4.5.1 binary.
The only export template it needs, the web one, `setup-server.sh`
downloads once (design log 0121).

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
   | `SUPABASE_PUBLISHABLE_KEY` | same page, publishable key (goes on the server, which hands it to players for logging in) |
   | `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID` | Google Cloud OAuth client ID |
   | `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET` | Google Cloud OAuth client secret |

   Then delete the four key files from your machine.
4. **Variables (optional)**, same page, Variables tab:
   `SERVER_DOMAIN` (default `flatland-online.duckdns.org`; `none` for
   plain `ws://` on the game port, no Caddy), `SERVER_PORT` (default
   `24680`, the game server's own port behind Caddy), `SERVER_TYPE` (default `cax11`, ARM, EU only), `SERVER_LOCATION`
   (default `nbg1`), `SERVER_NAME` (default `slice-server`). For the US use
   an x86 type such as `cpx11` and `ash` or `hil`. Check current type names
   in the Hetzner console; the workflow shows the API's error if one is wrong.
5. Push, then run **001-full-deploy** with *Create the server* ticked.

## On the server

- `/opt/godot/godot`: Godot.
- `/opt/slice/releases/<commit>/`: the last 5 deploys; `/opt/slice/current`
  points at the running one. Each has its web client in `build/web/`
  (export log: `build/web-export.log`).
- `/home/slice/.local/share/godot/export_templates/4.5.1.stable/`: the web
  export template.
- `slice.service`: the game server, WebSocket on TCP 24680 (log 0110). Logs: `journalctl -u slice -f`.
- `caddy.service`: 443 with a Let's Encrypt certificate. WebSocket
  upgrades (`wss://SERVER_DOMAIN`) go to the game on `127.0.0.1:24680`
  (log 0118); everything else is the web client from
  `/opt/slice/current/build/web` (log 0121). Config:
  `/etc/caddy/Caddyfile`, written by `setup-server.sh`. Logs:
  `journalctl -u caddy -f`.
- Firewall (`ufw`): 22, 80 and 443 only; the game port is closed to the
  internet when there's a domain.
- `slice-traffic-watch.timer`: every 15 min, stops the server at 80% of the
  traffic allowance.
- `/etc/slice/`: secrets installed by 001-full-deploy (root only):
  `hcloud.env` for the traffic watch, `server.env` (Supabase URL and secret
  key) passed to the game server as environment variables.

To log in yourself, add your own key in the Hetzner console before creating
the server, or use `slice_deploy` before deleting it.

## Notes

- Changing `DEPLOY_HOST_KEY` only applies to a newly created server.
- Players play at `https://flatland-online.duckdns.org/` (the web
  client) and join `wss://flatland-online.duckdns.org` (the game's
  `online/server_address`). The DuckDNS name is pointed at the server's IP
  by hand at duckdns.org; a new server (new IP) needs it updated there
  before 001-full-deploy, or Caddy can't get a certificate. 002-deploy-code
  ends by checking that `wss://` answers and the web client is served.
- Changing the domain: set `SERVER_DOMAIN`, run 001-full-deploy, change
  `online/server_address` in `project.godot`, and add the new page
  addresses to `additional_redirect_urls` in `supabase/config.toml`.
- Deploys need the server and every client on the same version
  (`application/config/version`, log 0109). The web client is redeployed
  with the server; a cached old one reloads itself when turned away.
  Desktop builds still need updating by hand.
- New server secrets get a check and an install step in
  `ci/install-secrets.sh`.
- Migrations must work with the server version still running (log 0105):
  add a column in one deploy, drop the old one in a later deploy.
