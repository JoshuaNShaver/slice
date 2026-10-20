# 0135: Web build takes SLICE_SERVER at export time

- **Date:** 2026-10-19
- **Status:** Accepted
- **Decision:** A web export made with `SLICE_SERVER` set joins that server
  (an editor export plugin, `addons/server_address`, writes it into the
  build); unset, it joins `online/server_address` (prod).
- **Why:** test the browser build against a local server without editing
  `project.godot`. A browser has no environment to read at runtime.
