# 0119: Main menu is Offline or Online; no hosting or address

- **Date:** 2026-10-18
- **Status:** Accepted
- **Decision:** The menu offers two modes, Offline and Online. Hosting a
  server from the menu, and the address and port fields, are gone. Online
  joins the game's server: the project setting `online/server_address`
  (`wss://flatland-online.duckdns.org`). On desktop `-- --server-address=`
  or `SLICE_SERVER` points it elsewhere (a dev or LAN server, which still
  runs with `-- --server`); the web build always uses the setting. The
  chosen mode is remembered. Changes 5b's "offline, host, or join" and log
  0110's web menu line.
- **Why:** players should never need to know an address; one server.
