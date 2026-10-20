# 0147: The josh role, and who imsdow talks to

- **Date:** 2026-10-19
- **Status:** Superseded by 0152
- **Decision:** A third account role, `josh` (`profiles.role`, set only in
  the database), is an admin in every way. imsdow talks to Josh in the
  first person (`assets/companion/imsdow.cfg`); to every other admin,
  including offline and a host's own player, she talks about Josh
  (`assets/companion/imsdow_about_josh.cfg`, lines only; settings stay in
  `imsdow.cfg`). The server tells each client its role when it logs in.
- **Why:** the user asked for it: her first-person lines are written to
  Josh, so other admins should hear about him, not as him.
