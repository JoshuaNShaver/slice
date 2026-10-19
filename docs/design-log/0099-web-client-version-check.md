# 0099: The web build is the main client; joining checks the version

- **Date:** 2026-10-18
- **Status:** Accepted
- **Decision:** The main way to play online is a web build in the browser.
  Servers accept WebSocket connections (ENet kept for desktop builds).
  On joining, the client sends its build version and the server turns away
  a mismatch with a "please update" message.
- **Why:** a browser always loads the newest build, so it is the easiest
  client to keep current and to share. Desktop builds still need the check.
