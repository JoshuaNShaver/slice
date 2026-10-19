# 0118: wss:// through Caddy at flatland-online.duckdns.org

- **Date:** 2026-10-18
- **Status:** Accepted
- **Decision:** The online server is `flatland-online.duckdns.org`, a free
  DuckDNS name pointed at the VPS by hand. `setup-server.sh` installs
  Caddy, which serves 443 with a Let's Encrypt certificate and passes
  WebSocket to the game server on `127.0.0.1:24680`. The firewall opens
  only 22, 80 and 443; the game port is closed to the internet. GitHub
  variables `SERVER_DOMAIN` (default the DuckDNS name; `none` for plain
  `ws://` on the game port) and `SERVER_PORT` (default 24680) feed setup;
  deploys check that `wss://` answers. Supersedes 0111.
- **Why:** HTTPS pages (itch.io) need `wss://`, and login tokens shouldn't
  cross the internet unencrypted. DuckDNS is free; a bought domain later
  only changes the address.
