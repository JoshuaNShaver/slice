# 0116: Online family slots live on the server

- **Date:** 2026-10-18
- **Status:** Proposed
- **Decision:** When joining, the menu connects and logs in first, then
  shows the account's 3 family slots as the server sent them. Founding,
  deleting and choosing a slot are requests to the server, which changes
  and saves its own copy and sends the slots back. Offline and hosting
  still show this machine's own slots. The menu shows who is logged in and
  a "Log out" button while joined to an online server.
- **Why:** the server owns saves (logs 0097, 0112), so the slots a player
  sees must be the server's.
