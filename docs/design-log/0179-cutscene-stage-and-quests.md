# 0179: A general cutscene stage, and quests as ordered steps

- **Date:** 2026-10-21
- **Status:** Accepted
- **Decision:** Cutscenes are data any server code can write: a cast of
  actors (shape, place on stage, size, a look: shape, line or straw
  dummy), and beats whose cues act on a named actor (move, fade, hop,
  jump onto another, fall, calipers, bells, halo, an arc joining two,
  dark). Settings come from a table (board, temple, yard, below, and a
  page of text). The server can run something once a cutscene ends.
  Quests are ordered lists of steps, each with goals to check off (talk
  to an NPC, kill so many of an enemy, wear an item, open a panel, win or
  lose a bout) and actions when a step starts or ends (a cutscene, a line,
  an item, a bout, healing). One script per quest, beside its cutscenes.
- **Why:** so cutscenes and quests can be used freely, without new drawing
  or plumbing for each.
