class_name RangerSchoolQuest
## The second quest (design log 0245): ranger school. A 50°+ triangle who
## reaches level 20, bootcamp behind them, is called back to the Drill
## Sergeant: they've been selected for the rangers, a special operations
## unit. Blindfolded, they're taken to an entrance exam, a platform course
## (RangerExam) where a Heroldt is already waiting at the end (log 0184).
## Then training on the rangers' island (RangerCamp), like bootcamp but with
## throwing tips: wild shapes, ranger recruits, and a bout with the Heroldt.
## Win or lose, the quest ends; the island and its stores stay open to you.
## Quests has the format.

const ID := "ranger_school"
const NAME := "Ranger school"
const SERGEANT := BootcampQuest.SERGEANT
const INSTRUCTOR := RangerCamp.INSTRUCTOR
## Darren's line, a generation on (log 0184). *Proposed* name.
const HEROLDT := "Edric Heroldt"
const TIPS := "points_10"  # Gear.item("points", Gear.SCOUT)
## From this step on you're in training: the island lets you in and you
## may wear ranger gear (trained_or_training).
const TRAINING_FROM := 2
const LEVEL := 20
const APEX := 50

const SERVES := "regulars"

const STEPS: Array = [
	{
		"text": "The Drill Sergeant has sent for you.",
		"goals": [{"talk": SERGEANT, "label": "Talk to the Drill Sergeant"}],
		"then": [{"cutscene": "selected",
				"lead": [SERGEANT, "There you are. Don't salute. Walk with me."]}],
	},
	{
		"text": "The entrance exam: find the way across the course. Fall and you start again. Left it? The Drill Sergeant will take you back.",
		"start": [{"travel": "exam"}],
		# Home (C) from the exam: the course goes, so the Sergeant sends you back to a fresh one.
		"back": [SERGEANT, "Back already? Hood on. Try it again.", [{"travel": "exam"}]],
		"goals": [{"reach": "exam_pass", "label": "Find the way across"}],
		"then": [{"say": [HEROLDT, "That's the pass. I came through it before breakfast. Come on: they're waiting."]}],
	},
	{
		"text": "Report to the Ranger Instructor.",
		"start": [{"travel": "camp"}],
		"goals": [{"talk": INSTRUCTOR, "label": "Talk to the Ranger Instructor"}],
		"then": [
			{"cutscene": "tips", "lead": [INSTRUCTOR, "So you're the one who came second. Over here."]},
			{"give": TIPS},
		],
	},
	{
		"text": "Put on your throwing tips.",
		"goals": [
			{"open": "character", "label": "Open your character sheet ({character_sheet})"},
			{"equip": TIPS, "label": "Wear the Scout tips"},
		],
		"nag": [INSTRUCTOR, ["Tips on, recruit. They're no use in your bag."]],
	},
	{
		"text": "Show the Ranger Instructor.",
		"goals": [{"talk": INSTRUCTOR, "label": "Talk to the Ranger Instructor"}],
		"then": [
			{"say": [INSTRUCTOR, "Good. Left click and they fly at the nearest foe. No need to aim: just keep your distance."]},
			{"say": [INSTRUCTOR, "Five wild shapes in the yard. Don't touch them. Throw."]},
		],
	},
	{
		"text": "Knock down the wild shapes in the camp's yard with your tips.",
		"goals": [{"kill": "dummy", "count": 5, "label": "Wild shapes"}],
		"nag": [INSTRUCTOR, [
			"Five wild shapes. Throw, don't charge.",
			"Left click. They seek the nearest foe on their own.",
		]],
	},
	{
		"text": "Report back to the Ranger Instructor.",
		"goals": [{"talk": INSTRUCTOR, "label": "Talk to the Ranger Instructor"}],
		"then": [
			{"say": [INSTRUCTOR, "Now the recruits. They throw back. Keep moving and don't stand where they're aiming."]},
		],
	},
	{
		"text": "Best the ranger recruits in the yard.",
		"goals": [{"kill": "ranger_recruit", "count": 5, "label": "Ranger recruits bested"}],
		"nag": [INSTRUCTOR, [
			"Five recruits. They pull their throws. You needn't.",
			"Their tips fly straight. Jump, and they miss.",
		]],
	},
	{
		"text": "Report back to the Ranger Instructor.",
		"goals": [{"talk": INSTRUCTOR, "label": "Talk to the Ranger Instructor"}],
		"then": [{"cutscene": "heroldt",
				"lead": [INSTRUCTOR, "Five for five. Heroldt! Down here. You've a bout."]}],
	},
	{
		"text": "Spar with Edric Heroldt in the yard. Four hits and the bout's lost.",
		"start": [{"spawn": "edric", "at": RangerCamp.BOUT_AT, "room": RangerCamp.YARD}],
		"goals": [{"spar": "edric", "label": "Spar with Edric Heroldt"}],
		"nag": [INSTRUCTOR, ["He's waiting in the yard. Keep your distance, and keep moving."]],
		"then": [
			{"cutscene": "won", "if": "won", "lead": [INSTRUCTOR, "Heroldt's down! That's the bout. Over here, both of you."]},
			{"cutscene": "lost", "if": "lost", "lead": [INSTRUCTOR, "That's the bout. Up you get, and over here."]},
			{"heal": true},
		],
	},
]

const SCENES: Array[String] = ["selected", "tips", "heroldt", "won", "lost"]

const INSTRUCTOR_LOOK := {"name": INSTRUCTOR, "sides": 3, "kind": "isosceles", "apex": 55,
		"wear": ["points_14", "plating_14", "", "eye_14", "voice_14"]}
const HEROLDT_LOOK := {"name": HEROLDT, "sides": 3, "kind": "isosceles", "apex": 55,
		"wear": ["points_10", "plating_10", "", "eye_10", "voice_10"]}


## Is a player like `you` called to ranger school? {sides, kind, apex,
## level, done: quest ids finished}. A 50°+ triangle at level 20, through
## bootcamp (log 0245).
static func offered(you: Dictionary) -> bool:
	if int(you.get("sides", 0)) != 3 or int(you.get("level", 0)) < LEVEL:
		return false
	if BootcampQuest.ID not in you.get("done", []):
		return false
	return str(you.get("kind", "")) == "equilateral" or int(you.get("apex", 0)) >= APEX


## Server only. Through ranger school, or far enough in to be training:
## the island lets them in and they may wear ranger gear (log 0241).
static func trained_or_training(p: PlayerShape) -> bool:
	if p.quests.is_done(ID):
		return true
	return p.quests.has_started(ID) and int(p.quests.state_of(ID).get("step", 0)) >= TRAINING_FROM


static func scene(id: String, you: Dictionary) -> Dictionary:
	match id:
		"selected":
			return {"acts": [_selected(you), _blindfold()]}
		"tips":
			return {"acts": [_tips(you)]}
		"heroldt":
			return {"acts": [_heroldt(you)]}
		"won":
			return {"acts": [_bout_over(you, true)]}
		"lost":
			return {"acts": [_bout_over(you, false)]}
	return {}


static func _you(you: Dictionary, x: float) -> Dictionary:
	return BootcampQuest._you(you, x)


## The Sergeant tells you you've been selected, and you're hooded.
static func _selected(you: Dictionary) -> Dictionary:
	var beats: Array = [
		Cutscenes.beat("sergeant", "Twenty, and still sharp. Sharper than most. Somebody's noticed."),
		Cutscenes.beat("sergeant", "There's a unit the General doesn't talk about. Special operations. They don't charge in. They see the enemy first and strike from far off."),
		Cutscenes.beat("sergeant", "The rangers. You've been selected for their school."),
		Cutscenes.beat("sergeant", "Don't ask me where it is. I've been, and I couldn't tell you. Nobody can."),
		Cutscenes.beat("sergeant", "First there's an exam. Pass it and they'll train you. Fail and you'll be back here, sweeping the yard."),
		Cutscenes.beat("sergeant", "Hold still.", [Cutscenes.on("hop", "sergeant")]),
	]
	return {"id": "ranger_selected", "setting": "yard", "place": "The drill yard", "beats": beats,
			"cast": [_you(you, 0.3), Cutscenes.actor("sergeant", BootcampQuest.SERGEANT_LOOK, 0.55, 44)]}


static func _blindfold() -> Dictionary:
	var beats: Array = [
		Cutscenes.beat("", "A hood comes down over your eye, and the world goes dark."),
		Cutscenes.beat("", "You are carried. Then rowed: a long way, and the sea is rough. Then carried again, and set down."),
		Cutscenes.beat("", "The hood comes off. Ahead of you, ledges hang over a pit, and climb away into the dark."),
	]
	return {"id": "ranger_blindfold", "setting": "card", "place": "Somewhere", "beats": beats, "cast": []}


## The Instructor, with the Heroldt who passed first, gives you your tips.
static func _tips(you: Dictionary) -> Dictionary:
	var beats: Array = [
		Cutscenes.beat("", "The rangers' island: cliffs on both sides, and the sea a long way down."),
		Cutscenes.beat("heroldt", "Edric. Of the family Heroldt. You'll have heard of us.", [Cutscenes.on("hop", "heroldt")]),
		Cutscenes.beat("heroldt", "I passed in the morning. Ledge to ledge, never touched the pit. My grandfather would have done it faster."),
		Cutscenes.beat("instructor", "Your grandfather fell in twice, Heroldt. Be quiet."),
		Cutscenes.beat("instructor", "A soldier fights with his corners. A ranger fights with these.", [Cutscenes.on("hop", "you")]),
		Cutscenes.beat("instructor", "Throwing tips. Small spinning points of steel. They fly at the nearest foe you can see: you needn't aim, only keep your distance."),
		Cutscenes.beat("instructor", "They hit softer than a corner. But a man who never gets close never gets hurt. Put them on."),
	]
	return {"id": "ranger_tips", "setting": "camp", "place": "The Rangers' Island", "beats": beats,
			"cast": [_you(you, 0.25), Cutscenes.actor("instructor", INSTRUCTOR_LOOK, 0.5, 44),
				Cutscenes.actor("heroldt", HEROLDT_LOOK, 0.75, 42)]}


static func _heroldt(you: Dictionary) -> Dictionary:
	var beats: Array = [
		Cutscenes.beat("instructor", "One bout. Tips only. Four hits and it's over."),
		Cutscenes.beat("heroldt", "Four? I'll only need two.", [Cutscenes.on("move", "heroldt", {"to": 0.8})]),
		Cutscenes.beat("instructor", "He throws fast and he backs off. Don't chase him into the cliff. Make him come to you."),
		Cutscenes.beat("", "He is already out in the yard, turning a tip over and over."),
	]
	return {"id": "ranger_heroldt", "setting": "camp", "place": "The Rangers' Island", "beats": beats,
			"cast": [_you(you, 0.3), Cutscenes.actor("instructor", INSTRUCTOR_LOOK, 0.5, 44),
				Cutscenes.actor("heroldt", HEROLDT_LOOK, 0.68, 42)]}


## After the bout, the end of school: the island and its stores are yours,
## and the General has ranger work.
static func _bout_over(you: Dictionary, won: bool) -> Dictionary:
	var beats: Array
	if won:
		beats = [
			Cutscenes.beat("", "Edric Heroldt sits down hard in the dirt of the yard."),
			Cutscenes.beat("heroldt", "...My family isn't going to hear about this."),
			Cutscenes.beat("heroldt", "You came second through the exam. You're not coming second at anything else, are you?"),
			Cutscenes.beat("instructor", "Good work. Both of you. Heroldt, stop sulking."),
		]
	else:
		beats = [
			Cutscenes.beat("", "The fourth tip catches you square, and the yard spins."),
			Cutscenes.beat("heroldt", "Told you. You chased. Everyone chases at first."),
			Cutscenes.beat("heroldt", "Throw, step back, throw. Let them come into it. You'll get it."),
			Cutscenes.beat("instructor", "He's right, which I'll only say once. You've the makings."),
		]
	beats.append(Cutscenes.beat("instructor", "That's school. You're a ranger now: the island's stores are open to you. Scout kit for chits; the rest for coin."))
	beats.append(Cutscenes.beat("instructor", "The General keeps ranger work for those who can do it. And the Drill Sergeant can bring you back here, any time."))
	beats.append(Cutscenes.beat("instructor", "The Ferryman will take you back. Don't look over the side."))
	return {"id": "ranger_bout_" + ("won" if won else "lost"), "setting": "camp", "place": "The Rangers' Island",
			"beats": beats,
			"cast": [_you(you, 0.3), Cutscenes.actor("instructor", INSTRUCTOR_LOOK, 0.52, 44),
				Cutscenes.actor("heroldt", HEROLDT_LOOK, 0.72, 42)]}
