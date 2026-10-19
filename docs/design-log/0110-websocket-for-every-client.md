# 0110: WebSocket for every client; ENet dropped

- **Date:** 2026-10-18
- **Status:** Proposed
- **Decision:** Hosts and dedicated servers listen with
  `WebSocketMultiplayerPeer` on TCP 24680, and desktop and web clients
  both join over WebSocket. ENet is no longer used. Changes log 0099's
  "ENet kept for desktop builds". A browser can't host, so the web menu
  offers only Offline and Join.
- **Why:** one `SceneMultiplayer` has one peer, so serving ENet and
  WebSocket together would need a custom bridging peer. One transport is
  simpler and also drops the ENet send-failure workaround. TCP can stall
  unreliable updates behind a lost packet; fine until we optimize.
