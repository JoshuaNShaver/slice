# 0115: Google login through Supabase, PKCE, checked by the server

- **Date:** 2026-10-18
- **Status:** Proposed
- **Decision:** After the version handshake, an online server sends the
  client its Supabase URL and publishable key (never the secret key; the
  server won't start if they match). The client logs in with Google by
  PKCE: desktop opens the system browser and catches the redirect on
  `127.0.0.1:47613–47615/auth/callback` (listed in `supabase/config.toml`);
  the web build sends the page to Supabase and finishes when it comes
  back (untested; itch.io's iframe likely needs a popup instead). The
  session is kept in `user://account/session.json` and refreshed, so
  players log in once. The client sends the access token; the server asks
  Supabase `/auth/v1/user` whose it is on each join, and uses that user
  id as the account. A refused token is forgotten and the menu shows "Log
  in with Google" again; 5 refusals or 5 minutes without logging in drop
  the connection. One account plays once per server at a time.
- **Why:** the client never handles a password or secret, and asking
  Supabase per join means a revoked session is refused at once.
