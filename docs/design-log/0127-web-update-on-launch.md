# 0127: The web client switches to a new build on its next launch

- **Date:** 2026-10-19
- **Status:** Proposed
- **Decision:** On each launch the web client asks for a newer build; one
  that finished downloading in the background is switched to on the
  following launch (the page reloads itself once). Never mid-session. The
  version-check reload (log 0122) stays for builds that can't play together.
- **Why:** the service worker serves the cached build first, so a deploy
  without a version change never reached phones and installed apps; a
  login fix sat unused on them.
