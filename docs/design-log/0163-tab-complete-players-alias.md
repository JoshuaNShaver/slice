# 0163: Tab completes commands; \players

- **Date:** 2026-10-20
- **Status:** Accepted
- **Decision:** In the terminal, Tab finishes the word being typed after
  `\`: command, verb, `\player set` field, `--flag`, or `\diag live` /
  `\simulate lag off`. Several matches complete to their shared start; Tab
  again lists them. Admin nouns are offered only to admins. `\players` is
  short for `\player list`, as `\enemies` is for `\enemy list`.
- **Why:** the user asked for it.
