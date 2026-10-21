class_name SaveKeeper
extends RefCounted
## Server only. When to write a playing account's family and chests to the
## store (design log 0113). The world calls checkpoint() every few
## seconds; a meaningful change (level, bag, gear, abilities, chests,
## quests) is
## saved at once, but no more often than MIN_GAP; anything else (XP, pay)
## waits for SAVE_EVERY. Leaving, dying and marrying save at once.

const MIN_GAP := 10.0  # s between saves of one player
const SAVE_EVERY := 45.0  # s, for changes that aren't meaningful

var store: SaveStore


## Quest progress is the account's (log 0183): saved with any family, or
## none (a family that just ended).
## `session` is an Accounts session: {"account", "families", "chest", "quests",
## "slot", "saved_at"}. `force` saves any change now.
func checkpoint(session: Dictionary, p: PlayerShape, force := false) -> void:
	_checkpoint_quests(session, p, force)
	var family: Family = _family(session)
	if family == null or p == null or p.generation != family.generation:
		return
	var progress := p.progress()
	var chest := Array(p.inventory.chest)
	var progress_changed := progress != family.progress
	var chest_changed: bool = chest != session.chest
	if not progress_changed and not chest_changed:
		return
	var since := _now() - float(session.saved_at)
	var meaningful: bool = chest_changed or _meaningful(family.progress, progress)
	if not force and since < SAVE_EVERY and not (meaningful and since >= MIN_GAP):
		return
	session.saved_at = _now()
	if progress_changed:
		family.progress = progress
		save_family(session)
	if chest_changed:
		session.chest = chest
		store.save_chest(session.account, chest)


## A quest step is as meaningful as a level: saved at once, at most every
## MIN_GAP (or now, when forced).
func _checkpoint_quests(session: Dictionary, p: PlayerShape, force: bool) -> void:
	if p == null or not session.has("quests"):
		return
	var quests := p.quests.save_data()
	if quests == session.quests:
		return
	var since := _now() - float(session.get("quests_saved_at", -INF))
	if not force and since < MIN_GAP:
		return
	session.quests = quests
	session.quests_saved_at = _now()
	store.save_quests(session.account, quests)


func save_family(session: Dictionary) -> void:
	var family: Family = _family(session)
	if family != null:
		store.save_family(session.account, session.slot, family.to_dict())


static func _family(session: Dictionary) -> Family:
	var slot: int = session.slot
	return session.families[slot] if slot >= 0 else null


static func _meaningful(before: Dictionary, after: Dictionary) -> bool:
	for key: String in ["level", "bag", "equipped", "abilities"]:
		# As JSON: a loaded save holds PackedStringArrays, a fresh one Arrays.
		if JSON.stringify(before.get(key)) != JSON.stringify(after.get(key)):
			return true
	return false


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
