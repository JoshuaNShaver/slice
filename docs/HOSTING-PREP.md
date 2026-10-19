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
5. **Accounts, server-owned saves, Google login** (logs 0112–0116,
   Proposed; version 0.2.0). The server owns saves (`scripts/saves/`:
   local files offline/LAN, Supabase online); Google login by PKCE
   (`scripts/auth/`, `Accounts`, `OnlineLogin`); online family slots in the
   menu. Server needs `SUPABASE_PUBLISHABLE_KEY` (new GitHub secret,
   installed by `001-full-deploy`). Loopback redirect URLs are in
   `supabase/config.toml`. Tests, all passing: `test_saves`,
   `test_supabase_store` and `test_auth` (against
   `tools/tests/supabase_mock.py`), `test_online` (guest server and
   Supabase-mode server on the mock), smoke test.
   - **Not yet tested for real:** a login with real Google + Supabase
     (manual steps below). Web login is untested and likely needs a popup
     on itch.io (iframe); its page URL must be added to `config.toml`.

### Manual test: real Google login (desktop)

1. Google Cloud: an OAuth client (type "Web application") with redirect
   URI `https://<project-ref>.supabase.co/auth/v1/callback`.
2. GitHub secrets: `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID` / `_SECRET`,
   and the new `SUPABASE_PUBLISHABLE_KEY`. Push and run **002-deploy-code**
   (applies the migration and `config.toml`), or `supabase config push` and
   `supabase db push` locally. Check Auth → URL Configuration in the
   dashboard lists the three `127.0.0.1:4761x` URLs.
3. Run a local server with the real keys:
   `SUPABASE_URL=https://<ref>.supabase.co SUPABASE_SECRET_KEY=sb_secret_… SUPABASE_PUBLISHABLE_KEY=sb_publishable_… Godot --headless --path . -- --server --port=24680 --save-dir=user://test-real/`
   (expect `Saves: Supabase at …; logins: supabase`).
4. Run the game from the editor, Join `127.0.0.1:24680`, press "Log in
   with Google", finish in the browser; the tab should say "Logged in".
   Found a family, play, level up, leave.
5. Check the `families` row in the Supabase table editor. Rejoin: no
   browser this time (saved session), same level. "Log out", rejoin:
   the Google button is back.
6. Second machine or second Google account at the same time: both play;
   the same account twice is refused.

## In progress (branches, not merged)

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

- Accept or reject Proposed logs 0106, 0107, 0109, 0110, 0111, 0112–0116
  (and later the prediction log). If 0110 is accepted, set 0099 to
  "Superseded by 0110".
- Choose a domain for `wss://`.

## Shipping rule

Online, server and clients must switch together (WebSocket and new RPC paths
broke old builds). When ready: push, run **001-full-deploy** once (opens TCP
24680 on the VPS), then ship the new desktop/web builds.
