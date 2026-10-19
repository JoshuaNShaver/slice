# 0123: Players choose a username; emails never show

- **Date:** 2026-10-18
- **Status:** Accepted
- **Decision:** After the first Google sign-in on an online server, the
  menu shows "Choose a username" before the family slots. A username is 3
  to 16 letters, numbers or `_`, unique ignoring case, and is set once. The
  server checks it and keeps it in a `profiles` table (user_id, username)
  that only its secret key can touch. The menu shows "Signed in as
  <username>" and "Signing in…" during sign-in; the client never shows the
  email. Guest (LAN, dev) servers don't ask.
- **Why:** an email is private; a username is what other players and the
  menu should see.
