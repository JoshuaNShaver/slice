# Flatland

A multiplayer Flatland roguelite, built with Godot 4.5 (GDScript).
The design lives in `docs/DESIGN.md`.

## Setup

You need Godot 4.5.1. The commands below use an alias for the macOS app
binary:

```sh
alias godot=/Applications/Godot.app/Contents/MacOS/Godot
```

Run every command from the project root (the folder with `project.godot`).

## Run a dedicated server

```sh
godot --headless --path . -- --server
```

- Listens on port `24680`. To use another port, add `--port=NNNN` after the `--`:
  `godot --headless --path . -- --server --port=25000`
- `--headless` runs it with no window. The server has no local player.
- It prints `Server listening on port 24680`, and a line each time a player
  joins or leaves. Stop it with `Ctrl+C`.

Options after the lone `--` belong to the game. Options before it belong to Godot.

## Run a game client

```sh
godot --path .
```

This opens the main menu. To join a server:

1. Choose **Join** in the server panel.
2. Enter the address (blank means `127.0.0.1`) and the port (default `24680`).
3. Pick a family slot to play.

You can also choose **Offline** for single player or **Host** to run a server
inside your own game. There's no command-line flag to auto-join yet, so
joining always goes through the menu.

### Several clients on one machine

Run `godot --path .` once per client, each in its own terminal. Each client
opens at 2560×1440, so give them smaller windows in different spots:

```sh
godot --path . --resolution 1280x720 --position 0,0
godot --path . --resolution 1280x720 --position 1300,0
```

All local clients share the same save folder, so they see the same three
family slots. Pick a different family in each client.

## Hot reload

When you run from source, the game and the server watch every `.gd` file.
Save a script and the running game picks up the new code within about half
a second, so you don't need to restart the server or the clients.

- Nodes keep their state (positions, health, and so on). New variables you
  add start at their default value.
- `_ready()` doesn't run again. A node can define `_hot_reload()` to rebuild
  itself after its script changes (the world rebuilds its HUD this way).
- A script with errors is skipped and the old code keeps running. Fix the
  error and save again.
- Scene (`.tscn`) changes and new autoloads still need a restart.

For a multiplayer test, edit server-side code and the dedicated server
reloads it. Edit client-side code and every client running from source
reloads it.

Hot reload runs only from source (the `editor` build, which is what the
commands above use). Exported builds never hot reload. To turn it off when
running from source, add `--no-hot-reload` after the `--`:

```sh
godot --headless --path . -- --server --no-hot-reload
godot --path . -- --no-hot-reload
```

## Check scripts

Parse every script and quit, without opening a window:

```sh
godot --headless --path . --quit-after 60
```
