# Exporting and LAN play

## Export the client (macOS)

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" build/Slice.zip
```

- Makes a universal `.app` (Apple Silicon + Intel) inside `build/Slice.zip`.
  End the path in `.app` instead to get the bare app.
- Use `--export-debug` for a build with the debug console.
- In the editor, the same export is **Project → Export → macOS → Export Project**.
- The preset lives in `export_presets.cfg`. The bundle identifier
  (`com.joshuashaver.slice`) is required, or the export fails.
- Export templates for 4.5.1 are installed. To build for Windows or Linux, add a
  preset in the Export dialog and export it by name the same way.
- Hot reload turns itself off in exported builds (it only runs with the
  `editor` feature).

## Export the web build

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web" build/web/index.html
```

- Players don't need this: every deploy exports the web client on the
  server and Caddy serves it at `https://flatland-online.duckdns.org/`
  (design log 0121). Export locally only to test.
- Uses the no-threads template, so it needs no special headers. It's an
  installable app (PWA, landscape) with on-screen touch controls on
  phones (log 0122); icons are in `web/`.
- The web build joins the prod server unless `SLICE_SERVER` is set when
  you export it (a browser has no environment, so the address goes into
  the build; log 0135). To play against a local server:
  `SLICE_SERVER=ws://127.0.0.1:24680 Godot --headless --path . --export-release "Web" build/web/index.html`.
  The export prints `Web build will join ...` when it's set. Deploys
  don't set it, so they get prod.
  `make web-local` does all of this (stop, export, server, web host) in
  one command.
- Test locally with `python3 -m http.server 8000 --directory build/web`
  and open `http://localhost:8000`. To try touch controls on a desktop
  browser, use its device toolbar (e.g. Chrome DevTools, phone mode). The
  offline cache only works over HTTPS or on `localhost`.
- Web renders with Compatibility (WebGL 2). Saves go to the browser's
  storage (IndexedDB), per site. A browser can't host, so the menu offers
  only Offline and Join.
- A page served over HTTPS can only join `wss://` servers, which the
  online server is (log 0118).

### Gatekeeper

Builds are ad-hoc signed and not notarized, so macOS blocks a downloaded copy.
Players can right-click the app and choose **Open**, or run
`xattr -cr Slice.app`. Getting rid of the warning needs an Apple Developer
account (signing + notarization).

## LAN play

On the same network there's nothing to open. Port forwarding is only for
players joining over the internet.

1. **Server:** on one machine run a dedicated server:
   `SAVES=local Godot --headless --path . -- --server --port=24680`. It
   listens for WebSocket connections on TCP port **24680**
   (`Net.DEFAULT_PORT`). The menu no longer hosts (design log 0119).
2. **Join:** on each player's machine start the game pointed at it,
   `Slice.app/Contents/MacOS/Slice -- --server-address=<server LAN IP>`
   (or set `SLICE_SERVER=<IP>`), and choose **Online**. The address can
   also be `host:port` or a full `ws://` / `wss://` URL. The server keeps
   your families (design log 0112), under its `user://accounts/`, by a
   device id of yours. The web build always joins the online server.
3. Client and server must run the same version (shown at the bottom right
   of the main menu); a mismatch is turned away with a message.

Find the host's LAN IP with `ipconfig getifaddr en0` (Wi-Fi) or
`ipconfig getifaddr en1` (Ethernet). The router assigns it, so it can change
after a restart.

### If a player can't connect

- **macOS firewall:** if it's on, allow incoming connections when macOS asks
  the first time Slice hosts. If you missed the prompt, add Slice under
  System Settings → Network → Firewall → Options.
- **Guest Wi-Fi:** guest networks and some office or campus networks keep
  devices from seeing each other. Put both machines on the main network.
- **Windows:** Windows Firewall may also ask to allow the game the first time
  it runs.
