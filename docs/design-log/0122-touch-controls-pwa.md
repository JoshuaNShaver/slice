# 0122: Touch controls, and the web client as an installable app

- **Date:** 2026-10-18
- **Status:** Accepted
- **Decision:** On a touch screen (from the start on phones and tablets;
  otherwise after the first touch, until a key is pressed) the HUD shows
  Genshin-style controls (`TouchControls`): a stick under the left thumb
  (left/right, analog); a big Jump button bottom right with the abilities
  you own in an arc around it (Rush, Nose dive, Spike up); Use and Take
  beside them only while there's something to use or take; Drink, Home,
  Bag and Menu along the top right. They press the same input actions as
  the keys. Hints name the buttons instead of keys. The quick slots move
  to the bottom center; the bag shows only while a panel is open. A phone
  held upright is asked to turn sideways. The web export is a PWA
  (installable, standalone, landscape) with the phone keyboard on for
  text fields. A web client turned away for its version activates the
  newest cached build and reloads, once per server version.
- **Why:** phones are a large share of browser players; joystick up/down
  for specials fires by accident while steering, so specials get buttons.
- **Open:** dropping items by touch (no right-click); HUD text size on
  small screens; the stick flick for specials as an option.
