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

### Gatekeeper

Builds are ad-hoc signed and not notarized, so macOS blocks a downloaded copy.
Players can right-click the app and choose **Open**, or run
`xattr -cr Slice.app`. Getting rid of the warning needs an Apple Developer
account (signing + notarization).

## LAN play

On the same network there's nothing to open. Port forwarding is only for
players joining over the internet.

1. **Host:** run the game (or a dedicated server:
   `Godot --headless --path . -- --server --port=24680`). It listens on
   UDP port **24680** (`Net.DEFAULT_PORT`).
2. **Join:** on the other machine, choose Join and enter the host's LAN IP
   and port 24680.

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
