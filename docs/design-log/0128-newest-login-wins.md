# 0128: The newest login takes the account over

- **Date:** 2026-10-19
- **Status:** Proposed
- **Decision:** An account is still online in one place per server, but a
  new login takes it over instead of being refused: the older connection is
  saved and sent away ("You signed in somewhere else."), and the new one
  gets the family screen with its families as just saved. Changes 0115's
  "one account plays once per server at a time".
- **Why:** a tab left open on one device locked the account out everywhere
  else, and the refused device forgot its sign-in, so it looked like
  sign-in was broken.
