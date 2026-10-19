# Hosting prep: status and what's left

Work toward public hosting (design log 0100). Update this file as steps land;
delete it when everything here is done.

## Done (on local `main`, not pushed yet)

1. **`PlayerShape` split into components** (log 0106, Proposed): `scripts/world/player_*.gd`.
   Smoke test: `Godot --headless --path . -s tools/tests/test_player.gd`.
2. **One script per ability** (log 0107, Proposed): `scripts/abilities/`.
3. **Version check on join** (log 0109, Proposed): `application/config/version`
   in `project.godot`, `scripts/autoload/handshake.gd`. Bump it on any change
   that breaks older clients (rule in CLAUDE.md).
4. **WebSocket for every client** (log 0110, Proposed; supersedes the "keep
   ENet for desktop" part of 0099) and a **Web export preset** (no threads).
   Deploy scripts use TCP 24680.

Checked together after merging: script check clean, smoke test passes, a
headless client joined a local server over WebSocket and its player synced.

## In progress (branches, not merged)

### `wip/accounts-saves-login` (logs 0112–0114, Proposed)
- **Step A, committed:** the server owns saves behind a `SaveStore` interface
  (`scripts/saves/`); `LocalFileStore` for offline; the server saves on
  meaningful events and every 45 s (log 0113).
- **Step B, committed:** Supabase migration
  `supabase/migrations/20261018120000_account_saves.sql` (RLS on, no client
  policies) and `SupabaseStore`; mock PostgREST at `tools/tests/supabase_mock.py`.
- **Step C, WIP commit, unfinished and untested:** Google login (PKCE,
  loopback catcher for desktop, `web_login.gd` for web), `accounts.gd`,
  `online_login.gd`, online family slots in the main menu.
- Before merging: finish step C; run its tests (`tools/tests/test_saves.gd`,
  `test_supabase_store.gd`, `test_online.gd`, `test_auth.gd`); check whether
  the server needs `SUPABASE_PUBLISHABLE_KEY` (then add it to
  `001-full-deploy.yml` → `deploy/ci/install-secrets.sh`); check
  `supabase/config.toml` redirect URLs (declared keys overwrite the dashboard);
  bump the version; write manual end-to-end steps (real Google + Supabase).

### `wip/client-prediction` (WIP commit, unfinished and untested)
- `scripts/world/player_predictor.gd`, changes to motion/input/smoother/abilities,
  an on/off setting in `graphics.gd` + HUD, a latency proxy `tools/lag_proxy.py`,
  probe clients in `tools/tests/predict_*.gd`.
- No design log yet (use the next free number). Before merging: finish, test
  with the lag proxy (prediction on vs. off: response time, correction size),
  check hits/teleports/elevators/death/abilities, decide on a version bump.

## Not started

- **Domain + `wss://`** (log 0111, Proposed): pick a domain, point it at the
  VPS, add Caddy to `deploy/setup-server.sh`. Needed before the web build on
  itch.io can reach the server.
- **itch.io page:** export Web preset, zip `build/web/`, upload as HTML,
  restricted (password).
- **Content as data** (log 0101): server sends items/abilities/shops/NPC text.
- **Supabase extras:** nightly DB backup workflow; keep-awake ping (free tier
  pauses after ~1 week idle).
- **Small:** web build shows missing-glyph boxes for ←/→ in the HUD hint
  (bundle a font or use text). Other big files to split: `hud.gd`,
  `enemy.gd`, `missions.gd`, `world.gd` (suggestions in log 0106's notes or ask).

## Waiting on the user

- Accept or reject Proposed logs 0106, 0107, 0109, 0110, 0111 (and later
  0112–0114 and the prediction log). If 0110 is accepted, set 0099 to
  "Superseded by 0110".
- Choose a domain for `wss://`.

## Shipping rule

Online, server and clients must switch together (WebSocket and new RPC paths
broke old builds). When ready: push, run **001-full-deploy** once (opens TCP
24680 on the VPS), then ship the new desktop/web builds.
