# 0166: Builds are named by commit; the web page switches to a new one

- **Date:** 2026-10-20
- **Status:** Accepted
- **Decision:** Each build has an id: the short commit hash, plus
  `-dirty.<hash of the uncommitted changes>` (BuildInfo). Exports carry it
  inside, and a web export also writes `build_id.txt` next to index.html;
  deploys pass the release's commit (no git history on the server), and a
  server run from source reads git. On launch the web page fetches
  `build_id.txt` past every cache and, if it names a different build,
  switches to it at once (once per build and tab). The menu shows the
  version with the build under it; the terminal header and `\diagnostics`
  show it too, with the server's. Versions still decide who can play
  together (0109).
- **Why:** without a version bump the browser kept serving a stale cached
  build (0127 only switches on the launch after), so changes went untested.
