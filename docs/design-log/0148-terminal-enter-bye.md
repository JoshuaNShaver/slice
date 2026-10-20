# 0148: Enter stays in the terminal; \bye; all of imsdow's lines

- **Date:** 2026-10-20
- **Status:** Accepted
- **Decision:** In the admin terminal, Enter never leaves (an empty line,
  plain chat, the chat key, a click away all keep it open); Esc or ✕
  closes it. `\bye` is never sent: imsdow says a `goodbye` line and waves,
  and the terminal closes 1.8 s later. Closing either way leaves her
  goodbye in the chat log ("imsdow: ..."). Every `[lines]` list in her
  file is read, each said when: `late_night` greets you midnight to 5 am
  instead of `hello`; `dozing` when she falls asleep after a quiet spell
  (`asleep` when she's found asleep); `reflections` join puns and lore;
  `repeat` for the same command twice; after the server's answer,
  `unknown` (no such command), `stuck` (`\enemies` found one AWAY) or
  `power` (`\player set`/`levelup` worked); `blushing` when she blushes
  by herself. Test: `tools/tests/test_imsdow.gd`.
- **Why:** the user added these lists and asked for Enter to stay and
  `\bye` to say goodbye.
