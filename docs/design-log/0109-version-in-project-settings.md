# 0109: The version lives in project.godot; one handshake checks it

- **Date:** 2026-10-18
- **Status:** Proposed
- **Decision:** The build version is `application/config/version` in
  `project.godot` (`Net.version`), shown on the main menu. Client and
  server must match exactly. On connecting, the client says hello with its
  version (`scripts/autoload/handshake.gd`, RPCs that never change); the
  server answers welcome, or sends "This server runs version X; you have
  Y. Please update" and closes the connection 2 s later. Only welcomed
  clients may register. Bump the version with any change an older client
  or server couldn't play with (RPCs, synced state, content); CLAUDE.md
  says so.
- **Why:** project.godot ships in every export and is read the same when
  the VPS runs from source. A git hash would turn away clients on every
  deploy, even docs-only ones.
