# 0217: Admin commands for world resources

- **Date:** 2026-10-22
- **Status:** Accepted
- **Decision:** `resources list [which] [--kind tree|ore] [--felled] [--standing]` lists trees and ore rocks (health left, or when each grows back; where; how far). `resources deplete <which|all> [--kind] [--id who] [--bag]` spends them at once, every drop still due going to `who`: on the ground beside each, as a hit's would, or with `--bag` in the bag (what doesn't fit on the ground). `resources regrow <which|all>` grows spent ones back now. `which` is a name or a `*` pattern.
- **Why:** testing logging, ore, the market and the Blacksmith without chopping by hand.
