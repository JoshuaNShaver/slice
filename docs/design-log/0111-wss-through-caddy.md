# 0111: wss:// through Caddy once the server has a domain

- **Date:** 2026-10-18
- **Status:** Proposed
- **Decision:** A web page served over HTTPS (itch.io) may only open
  `wss://`. Plan: point a domain (or subdomain) at the VPS, run Caddy on
  443 with an automatic Let's Encrypt certificate, and proxy WebSocket to
  the game server on 127.0.0.1:24680. Players then join
  `wss://<domain>`; the client already accepts a full `ws://` or `wss://`
  URL as the address. Until then the server takes plain `ws://` only.
- **Open:** which domain. Needs one before the web build on itch.io can
  play online.
