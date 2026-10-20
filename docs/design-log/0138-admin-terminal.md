# 0138: The admin terminal and its companion

- **Date:** 2026-10-19
- **Status:** Superseded by 0139
- **Decision:** A chat line starting with `\` turns the chat into a
  full-screen terminal until it closes: a dark backdrop ~60% see-through,
  DejaVu Sans Mono, green answers, typed commands echoed after an
  `admin@slice:~$` prompt. An ASCII anime girl (`ConsoleCompanion`) waves on
  opening, blinks, and says a random hello; bottom right on wide screens,
  top right (smaller) on narrow ones. Client-side only.
- **Why:** the user asked for it; fixed-width text also lines up the
  command tables.
