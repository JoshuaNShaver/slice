class_name PlayerQuests
extends Node
## A player's quests (PlayerShape's "Quests", design log 0179): where they
## are in each one (Quests has the format), what counts toward its goals,
## and its actions: cutscenes, lines, items, a bout. The server keeps the
## state, saved with the account (SaveKeeper, log 0183): it's the player's,
## so it carries on to heirs and to new families.
## The owner's HUD shows `tracker`.

var player: PlayerShape
## Synced: the quest the HUD shows, {"quest", "text", "goals": [[label,
## have, need], ...], "talk_to": an NPC's name or ""}, or {} for none.
var tracker: Dictionary = {}

## Seconds per character a cutscene's lead line stays up before the
## cutscene starts (at least LEAD_MIN). Tests set it to 0: no pause.
var lead_pace := 0.04
const LEAD_MIN := 2.0

var _state: Dictionary = {}  # server: quest id -> {"step", "counts"}
var _bouts: Dictionary = {}  # server: quest id -> its bout's Enemy


func _ready() -> void:
	if multiplayer.is_server():
		_resume.call_deferred()


func _exit_tree() -> void:
	for id: String in _bouts.keys():
		_end_bout(id)


# --- Saving ----------------------------------------------------------------

## What the family save keeps (PlayerSave).
func save_data() -> Dictionary:
	return _state.duplicate(true)


## The account's saved state (already sanitized, Quests.sanitize).
func load_data(saved: Dictionary) -> void:
	_state = saved.duplicate(true)


## After loading: bring back any bout the current step needs, and the HUD.
func _resume() -> void:
	for id: String in _state:
		if not _active(id):
			continue
		var step := _step(id)
		for action: Dictionary in step.get("start", []):
			if action.has("spawn") or action.has("travel"):
				_act(id, action)
	check_offers()
	_update_tracker()


## Server only. The shape changed (an heir): a quest it can't take part in
## waits, and its bout goes; one it can comes back.
func shape_changed() -> void:
	for id: String in _bouts.keys():
		if not _active(id):
			_end_bout(id)
	_resume()


# --- State -----------------------------------------------------------------

func has_started(id: String) -> bool:
	return _state.has(id)


## Under way, and this shape can take part (Quests.serves).
func _active(id: String) -> bool:
	return not is_done(id) and Quests.serves(id, player.sides, player.kind)


func is_done(id: String) -> bool:
	return _state.has(id) and int(_state[id].step) >= Quests.steps(id).size()


## Server only. Starts quest `id` at its first step, unless it's begun.
func start(id: String) -> bool:
	if not Quests.ALL.has(id) or has_started(id):
		return false
	_state[id] = {"step": 0, "counts": _blank_counts(id, 0)}
	_update_tracker()
	_run(id, _step(id).get("start", []), "")
	return true


## Server only. A birth's cutscene (a new family's first, or a marriage's)
## is about to play: start any quest offered at this birth, and add its
## intro to what's said once the cutscene ends. Returns the scene.
func after_birth(scene: Dictionary, newborn: Dictionary) -> Dictionary:
	for id: String in Quests.ALL:
		var quest: Script = Quests.ALL[id]
		if not quest.get("AT_BIRTH") or has_started(id) or not quest.offered(newborn):
			continue
		start(id)
		var wake: Array = []
		var speaker := str(scene.get("wake_speaker", ""))
		for line: Variant in scene.get("wake", []):
			wake.append(line if line is Array else [speaker, line])
		for line: String in quest.get("INTRO"):
			wake.append([quest.get("INTRO_SPEAKER"), line])
		scene.wake = wake
	return scene


## Server only. Starts any quest (not one offered at a birth) that this
## player is now called to: reached its level, finished what it follows
## (ranger school, log 0245).
func check_offers() -> void:
	if not multiplayer.is_server():
		return
	var done: Array = []
	for id: String in _state:
		if is_done(id):
			done.append(id)
	var you := {"sides": player.sides, "kind": player.kind, "apex": player.apex,
			"level": player.stats.level, "done": done}
	for id: String in Quests.ALL:
		var quest: Script = Quests.ALL[id]
		if quest.get("AT_BIRTH") or has_started(id) or not Quests.serves(id, player.sides, player.kind):
			continue
		if quest.offered(you):
			start(id)
			player.screen.tell("", "New quest: %s." % Quests.quest_name(id))


## Server only. Quest `id`'s place, {"step", "counts"}, or {} if it hasn't
## begun.
func state_of(id: String) -> Dictionary:
	return (_state.get(id, {}) as Dictionary).duplicate(true)


## Server only, for admins (`players quests set`, log 0196): puts quest `id`
## on step `at` (its step count is done), counts at 0, begun or not. As when
## a save loads on that step, only a bout it needs comes back (a fresh one);
## its other start actions don't run. Saved as any step is (SaveKeeper).
func jump_to(id: String, at: int) -> void:
	var had_bout := is_instance_valid(_bouts.get(id))
	_end_bout(id)
	_state[id] = {"step": at, "counts": _blank_counts(id, at)}
	_update_tracker()
	if had_bout:
		await get_tree().process_frame  # the old bout's gone, so the new one can take its name
	if is_inside_tree():
		_resume()


## Server only, for admins (`players quests delete`): as if quest `id` never
## began, so it can start again.
func forget(id: String) -> void:
	_end_bout(id)
	_state.erase(id)
	_update_tracker()


func _step(id: String) -> Dictionary:
	var quest_steps := Quests.steps(id)
	var at := int(_state[id].step) if _state.has(id) else 0
	return quest_steps[at] if at < quest_steps.size() else {}


func _blank_counts(id: String, at: int) -> Array:
	var quest_steps := Quests.steps(id)
	var counts: Array = []
	if at < quest_steps.size():
		for _goal in quest_steps[at].get("goals", []):
			counts.append(0)
	return counts


# --- Events ----------------------------------------------------------------

## Server only. Something happened that a goal may wait for (Quests.EVENTS):
## `what` happened `event`-wise, e.g. ("kill", "dummy").
func notify(event: String, what: String, outcome := "") -> void:
	for id: String in _state.keys():
		if not _active(id):
			continue
		var step := _step(id)
		var goals: Array = step.get("goals", [])
		var counts: Array = _state[id].counts
		var changed := false
		for i in goals.size():
			if Quests.goal_event(goals[i]) == [event, what] and counts[i] < Quests.need(goals[i]):
				counts[i] += 1
				changed = true
		if changed:
			_check_step(id, outcome)


## Server only. You pressed interact by the NPC named `npc_name`. True if a
## quest had something to say (the NPC's own lines are skipped).
func talk(npc_name: String) -> bool:
	for id: String in _state.keys():
		if not _active(id):
			continue
		var step := _step(id)
		for goal: Dictionary in step.get("goals", []):
			if Quests.goal_event(goal) == ["talk", npc_name]:
				notify("talk", npc_name)
				return true
		var back: Array = step.get("back", [])
		if back.size() == 3 and back[0] == npc_name:
			player.screen.tell(npc_name, str(back[1]))
			for action: Dictionary in back[2]:
				_act(id, action)
			return true
		var nag: Array = step.get("nag", [])
		if nag.size() == 2 and nag[0] == npc_name:
			player.screen.tell(npc_name, (nag[1] as Array).pick_random())
			return true
	return false


## Owner side: you did something only your machine sees (Quests.CLIENT_EVENTS),
## e.g. opened your character sheet. Sent only while a goal waits for it.
func report(event: String, what: String) -> void:
	if _waiting_for(event, what):
		_submit_report.rpc_id(1, event, what)


@rpc("any_peer", "call_local", "reliable")
func _submit_report(event: String, what: String) -> void:
	if not player.from_owner() or what not in Quests.CLIENT_EVENTS.get(event, []):
		return
	notify(event, what)


## Owner side, from the tracker: is a shown goal waiting for this?
func _waiting_for(event: String, what: String) -> bool:
	for goal: Array in tracker.get("goals", []):
		if goal.size() > 3 and goal[3] == event and goal[4] == what and goal[1] < goal[2]:
			return true
	return false


# --- Steps and actions -----------------------------------------------------

## Done if every goal is: run its "then", and the next step's "start".
func _check_step(id: String, outcome: String) -> void:
	var step := _step(id)
	var goals: Array = step.get("goals", [])
	var counts: Array = _state[id].counts
	for i in goals.size():
		if counts[i] < Quests.need(goals[i]):
			_update_tracker()
			return
	var next := int(_state[id].step) + 1
	_state[id] = {"step": next, "counts": _blank_counts(id, next)}
	var actions: Array = step.get("then", []).duplicate()
	if is_done(id):
		actions.append({"done": true})
	else:
		actions.append_array(_step(id).get("start", []))
	_update_tracker()
	_run(id, actions, outcome)


## Runs `actions` from `from` on, in order. A cutscene waits for its end,
## then the rest run (Net.play_cutscene).
func _run(id: String, actions: Array, outcome: String, from := 0) -> void:
	for i in range(from, actions.size()):
		var action: Dictionary = actions[i]
		if action.has("if") and action["if"] != outcome:
			continue
		if action.has("cutscene"):
			var lead: Array = action.get("lead", [])
			if lead.size() == 2 and lead_pace > 0.0:
				# Someone speaks first; the cutscene follows once it's been read.
				player.screen.tell(str(lead[0]), str(lead[1]))
				var pause := maxf(LEAD_MIN, str(lead[1]).length() * lead_pace)
				get_tree().create_timer(pause).timeout.connect(_play.bind(id, actions, outcome, i))
			else:
				_play(id, actions, outcome, i)
			return
		_act(id, action)


## Plays the cutscene at actions[at], then runs the rest once it ends.
func _play(id: String, actions: Array, outcome: String, at: int) -> void:
	if not is_inside_tree():
		return  # left the game during the lead line
	var quest: Script = Quests.ALL[id]
	var scene: Dictionary = quest.scene(str(actions[at].cutscene), _you())
	Net.play_cutscene(player.peer_id, scene, _run.bind(id, actions, outcome, at + 1))


func _act(id: String, action: Dictionary) -> void:
	if action.has("say"):
		player.screen.tell(str(action.say[0]), str(action.say[1]))
	elif action.has("give"):
		var item := str(action.give)
		player.screen.tell("", "Received: %s." % Gear.item_name(item))
		if not player.inventory.add_to_bag(item):
			_world().drop_item(item, player.peer_id, player.position)
	elif action.has("spawn"):
		_spawn_bout(id, action)
	elif action.has("heal"):
		player.combat.heal_full()
	elif action.has("travel"):
		var world := _world()
		if world != null and world.has_method("travel"):
			world.travel(player, str(action.travel))
	elif action.has("done"):
		player.screen.tell("", "Quest complete: %s." % Quests.quest_name(id))
		check_offers.call_deferred()  # one quest may lead to the next


## You as a cutscene casts you (Quests: scene(id, you)).
func _you() -> Dictionary:
	return {"family": player.family_name, "sides": player.sides, "kind": player.kind, "apex": player.apex,
			"equipped": Array(player.inventory.equipped)}


## The world (spawn_enemy, drop_item, reward_kill); untyped, so a test's
## stand-in will do.
func _world() -> Node:
	return get_tree().get_first_node_in_group(World.GROUP)


# --- Bouts -----------------------------------------------------------------

## A bout (a "spawn" action): an enemy only you fight. Its first landed hit
## is its opening; a second ends the bout lost. Bring it down and it's won.
func _spawn_bout(id: String, action: Dictionary) -> void:
	if is_instance_valid(_bouts.get(id)):
		return
	var type := str(action.spawn)
	var info: Dictionary = Enemy.TYPES[type]
	var at: Vector2 = action.get("at", player.position)
	var enemy: Enemy = _world().spawn_enemy({
		"name": "Q%d_%s" % [player.peer_id, type],
		"type": type,
		"pos": at - Vector2(0, float(info.radius) + 10.0),
		"room": action.get("room", Rect2(at - Vector2(600, 600), Vector2(1200, 800))),
		"owner": player.peer_id,
	})
	_bouts[id] = enemy
	enemy.died.connect(_bout_won.bind(id), CONNECT_ONE_SHOT)
	enemy.struck.connect(_bout_struck.bind(id))


func _bout_struck(enemy: Enemy, _p: PlayerShape, id: String) -> void:
	var limit := int(enemy.info().get("bout_hits", 2))
	if enemy.hits_landed == limit - 1:
		enemy.shout("Ha! One more like that and the bout's mine.")
	elif enemy.hits_landed >= limit:
		_end_bout.call_deferred(id)
		notify.call_deferred("spar", enemy.type, "lost")


func _bout_won(enemy: Enemy, id: String) -> void:
	_world().reward_kill(enemy, false)
	_end_bout.call_deferred(id)
	notify.call_deferred("spar", enemy.type, "won")


func _end_bout(id: String) -> void:
	var enemy: Variant = _bouts.get(id)
	_bouts.erase(id)
	if is_instance_valid(enemy):
		(enemy as Enemy).queue_free()


# --- The HUD's tracker -----------------------------------------------------

## The first quest under way, as the owner's HUD shows it.
func _update_tracker() -> void:
	var shown := {}
	for id: String in Quests.ALL:
		if not has_started(id) or not _active(id):
			continue
		var step := _step(id)
		var goals: Array = []
		var talk_to := ""
		var counts: Array = _state[id].counts
		for i in (step.get("goals", []) as Array).size():
			var goal: Dictionary = step.goals[i]
			var event := Quests.goal_event(goal)
			goals.append([str(goal.get("label", "")), counts[i], Quests.need(goal), event[0], event[1]])
			if event[0] == "talk" and counts[i] < Quests.need(goal):
				talk_to = event[1]
		shown = {"quest": Quests.quest_name(id), "text": str(step.get("text", "")), "goals": goals,
				"talk_to": talk_to}
		break
	tracker = shown  # a new Dictionary each time, so the change is synced
