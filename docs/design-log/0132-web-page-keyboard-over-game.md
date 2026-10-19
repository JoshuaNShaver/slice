# 0132: Our own web page: the keyboard covers the game, no black bar

- **Date:** 2026-10-19
- **Status:** Accepted
- **Decision:** The web export uses our own HTML page (`web/shell.html`).
  The phone keyboard opens over the game instead of resizing or scrolling
  it: the page is pinned, the game keeps its size while typing, and
  Godot's hidden text box sits as a 1px box at the top so the browser
  never scrolls toward it. The main menu lifts a focused text field above
  the keyboard itself. The page background is parchment, not black, and
  the page re-measures and scrolls to the top after launch, so the
  installed app doesn't open offset with a black bar.
- **Why:** each keypress scrolled or resized the game; the installed app
  opened pushed down until tapped.
