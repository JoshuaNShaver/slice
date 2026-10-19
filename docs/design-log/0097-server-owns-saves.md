# 0097: The server owns saves, behind one storage interface

- **Date:** 2026-10-18
- **Status:** Accepted
- **Decision:** Families, progress and chests are loaded and saved by the
  server, never sent up by the client. All saving goes through one storage
  interface (load/save a player's data by account). Offline play uses the
  same interface over local files; an online server uses Supabase.
- **Why:** today a client sends its own save on joining, so anyone can
  edit their file. One interface keeps offline and online on the same code.
