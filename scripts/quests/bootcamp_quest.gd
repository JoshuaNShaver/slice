class_name BootcampQuest
## The first quest (design log 0181): the drill yard's bootcamp, and the
## start of a long friendship and rivalry with Darren Heroldt, your senior.
## The Priest sends you to the Drill Sergeant; he shows you how corners
## hurt, then sets you on the straw dummies, the recruits, your first
## armor, and a bout with Darren. Quests has the format.

const ID := "bootcamp"
const NAME := "Bootcamp"
const SERGEANT := "The Drill Sergeant"
const DARREN := "Darren Heroldt"
const LEATHER_PLATING := "plating_5"  # Gear.item("plating", Gear.LEATHER)
## Where Darren waits for your bout: inside the yard's east fence, clear of
## the dummies and the recruits.
const BOUT_AT := Vector2(-2690, Barracks.FLOOR_Y)

## Who can take part (Regions.admits): irregulars can't reach the barracks.
## Quest progress is the player's (log 0183), so with an irregular family it
## waits for the next regular one.
const SERVES := "regulars"

## Started at every regular birth (a family's first, or a foundling heir
## sent up), once per player.
const AT_BIRTH := true
const INTRO_SPEAKER := "The Priest"
const INTRO: Array[String] = [
	"There you are, and grown! The Board has your papers in order.",
	"The State has need of you. Report to the Drill Sergeant: west, through the barracks gate.",
]

const STEPS: Array = [
	{
		"text": "Report to the Drill Sergeant, west through the barracks gate.",
		"goals": [{"talk": SERGEANT, "label": "Talk to the Drill Sergeant"}],
		"then": [{"cutscene": "rundown",
				"lead": [SERGEANT, "Recruit, you're late! Get the lead out: we need to get you trained up."]}],
	},
	{
		"text": "Knock down the straw dummies in the drill yard. Jump on them, corner first.",
		"goals": [{"kill": "dummy", "count": 5, "label": "Straw dummies"}],
		"nag": [SERGEANT, [
			"Five dummies, recruit. Corners first.",
			"Jump on them. Come down point first.",
			"Jump again as you land. Off a corner, you'll fly.",
		]],
	},
	{
		"text": "Report back to the Drill Sergeant.",
		"goals": [{"talk": SERGEANT, "label": "Talk to the Drill Sergeant"}],
		"then": [
			{"say": [SERGEANT, "Five down! The straw's never been so sorry."]},
			{"say": [SERGEANT, "Now the recruits, past the dummies. Five bouts. They pull their punches: they'll never take your last point of health."]},
		],
	},
	{
		"text": "Spar with the recruits in the drill yard.",
		"goals": [{"kill": "sparring", "count": 5, "label": "Recruits bested"}],
		"nag": [SERGEANT, [
			"Five bouts with the recruits. They pull their punches. You needn't.",
			"Low on health? Step out of the yard and let it come back.",
		]],
	},
	{
		"text": "Report back to the Drill Sergeant.",
		"goals": [{"talk": SERGEANT, "label": "Talk to the Drill Sergeant"}],
		"then": [
			{"cutscene": "leather", "lead": [SERGEANT, "Five for five! Over here, recruit. I've got something for you."]},
			{"give": LEATHER_PLATING},
		],
	},
	{
		"text": "Put on the leather plating.",
		"goals": [
			{"open": "character", "label": "Open your character sheet ({character_sheet})"},
			{"equip": LEATHER_PLATING, "label": "Wear the leather plating"},
		],
		"nag": [SERGEANT, [
			"Open your character sheet and put that plating on, recruit.",
			"Armor's no use in your bag.",
		]],
	},
	{
		"text": "Show the Drill Sergeant your armor.",
		"goals": [{"talk": SERGEANT, "label": "Talk to the Drill Sergeant"}],
		"then": [{"cutscene": "darren",
				"lead": [SERGEANT, "Leather suits you. Now, there's someone you ought to meet."]}],
	},
	{
		"text": "Spar with Darren Heroldt in the drill yard. Mind his spike.",
		"start": [{"spawn": "darren", "at": BOUT_AT, "room": Barracks.YARD}],
		"goals": [{"spar": "darren", "label": "Spar with Darren"}],
		"nag": [SERGEANT, [
			"Go on. Darren's waiting in the yard.",
			"When he plants his point and shouts, get clear.",
		]],
		"then": [
			{"cutscene": "darren_won", "if": "won",
					"lead": [SERGEANT, "Down goes Heroldt! That's the bout. Over here, the pair of you."]},
			{"cutscene": "darren_lost", "if": "lost",
					"lead": [SERGEANT, "That's the bout! On your feet, recruit, and over here."]},
			{"heal": true},
		],
	},
]

const SCENES: Array[String] = ["rundown", "leather", "darren", "darren_won", "darren_lost"]

## How the Sergeant and Darren look on stage. The Sergeant wears full
## steel, so he stands out beside Darren's leather.
const SERGEANT_LOOK := {"name": SERGEANT, "sides": 3, "kind": "isosceles", "apex": 45,
		"wear": ["points_8", "plating_8", "", "eye_8", "voice_8"]}
const DARREN_LOOK := {"name": DARREN, "sides": 3, "kind": "isosceles", "apex": 35,
		"wear": ["points_5", "plating_5", "", "eye_5", "voice_5"]}
const DUMMY_LOOK := {"name": "Straw dummy", "sides": 4, "kind": "regular", "look": "dummy"}


static func offered(newborn: Dictionary) -> bool:
	return str(newborn.get("kind", "")) != "irregular"


static func scene(id: String, you: Dictionary) -> Dictionary:
	match id:
		"rundown":
			return {"acts": [_rundown(you)]}
		"leather":
			return {"acts": [_leather(you)]}
		"darren":
			return {"acts": [_darren(you)]}
		"darren_won":
			return {"acts": [_bout_over(you, true)]}
		"darren_lost":
			return {"acts": [_bout_over(you, false)]}
	return {}


## You, on stage: your shape and what you're wearing.
static func _you(you: Dictionary, x: float) -> Dictionary:
	return Cutscenes.actor("you", {"name": str(you.get("family", "You")), "sides": int(you.get("sides", 3)),
			"kind": str(you.get("kind", "isosceles")), "apex": int(you.get("apex", 40)),
			"wear": Array(you.get("equipped", []))}, x, 40)


## The Sergeant's first lesson (shown in full the first time): corners
## hurt, sharper hurts more, hit moving, best from above. He shows you on
## a dummy, and jumps far higher than you'd think.
static func _rundown(you: Dictionary) -> Dictionary:
	var beats: Array = [
		Cutscenes.beat("", "The drill yard: straw on stakes, a rail fence, and a Sergeant whose point has seen the front."),
		Cutscenes.beat("sergeant", "The Priest sent you? Good. Stand there, and don't touch anything."),
		Cutscenes.beat("sergeant", "Lesson one. Only corners hurt. Land a face on a man and you've shaken his hand. Land a corner and you've made your point."),
		Cutscenes.beat("sergeant", _your_corners(you)),
		Cutscenes.beat("sergeant", "Lesson two. A corner has to be moving. Roll into them hard, or better, come down on them from above. Watch the straw."),
		Cutscenes.beat("sergeant", "Hup!", [Cutscenes.on("jump", "sergeant", {"onto": "dummy", "height": 0.45, "hit": "9001"})]),
		Cutscenes.beat("", "He goes up like a struck match, higher than any triangle of his years has a right to, and comes down point first.",
				[Cutscenes.on("fall", "dummy")]),
		Cutscenes.beat("sergeant", "Nine thousand and one. You won't manage that, not for years. Jump again just as you land and you'll go higher; off a corner, higher still."),
		Cutscenes.beat("sergeant", "Lesson three. Your health, top left. Lose all of it and your line ends: no heir, no family, nothing. The straw won't hurt you. The Revolt will."),
		Cutscenes.beat("sergeant", "Five dummies. Knock them flat, then come back to me.", [Cutscenes.on("hop", "you")]),
	]
	return {"id": "bootcamp_rundown", "setting": "yard", "place": "The drill yard", "beats": beats,
			"cast": [
				_you(you, 0.14),
				Cutscenes.actor("sergeant", SERGEANT_LOOK, 0.34, 44),
				Cutscenes.actor("dummy", DUMMY_LOOK, 0.64, 32),
				Cutscenes.actor("dummy2", DUMMY_LOOK, 0.82, 32),
			]}


## What the Sergeant says of your corners.
static func _your_corners(you: Dictionary) -> String:
	var sides := int(you.get("sides", 3))
	if sides == 3 and str(you.get("kind", "")) != "equilateral":
		return "You're %d degrees at the apex. Sharp. The sharper the corner, the harder it bites, so keep that end toward the enemy." % int(you.get("apex", 40))
	if sides == 3:
		return "Sixty degrees, every corner. No sharp end and no blunt one: whichever comes down, it bites."
	return "%d corners, and blunter than a triangle's. But roll over a man and every one of them bites in turn." % sides


## Five recruits down: your first armor.
static func _leather(you: Dictionary) -> Dictionary:
	var beats: Array = [
		Cutscenes.beat("sergeant", "You're starting to look like a soldier. Starting."),
		Cutscenes.beat("sergeant", "Here. Leather plating, off the yard's own pile. It's taken worse than you'll give it.", [Cutscenes.on("hop", "you")]),
		Cutscenes.beat("sergeant", "Armor won't change your corners. It takes the edge off theirs."),
		Cutscenes.beat("sergeant", "Open your character sheet and put it on. Then come and show me."),
	]
	return {"id": "bootcamp_leather", "setting": "yard", "place": "The drill yard", "beats": beats,
			"cast": [_you(you, 0.3), Cutscenes.actor("sergeant", SERGEANT_LOOK, 0.55, 44)]}


## The Sergeant introduces your senior, Darren Heroldt, and sets a bout.
static func _darren(you: Dictionary) -> Dictionary:
	var beats: Array = [
		Cutscenes.beat("sergeant", "Almost a soldier. Almost."),
		Cutscenes.beat("", "Someone has been leaning on the fence, watching. He straightens up.", [Cutscenes.on("move", "darren", {"to": 0.7})]),
		Cutscenes.beat("sergeant", "Recruit, your senior: Darren, of the family Heroldt. A year ahead of you in the yard, and he never lets anyone forget it."),
		Cutscenes.beat("darren", "Heroldt. Like a herald, only louder.", [Cutscenes.on("hop", "darren")]),
		Cutscenes.beat("darren", "So you knocked over the straw. Everyone knocks over the straw."),
		Cutscenes.beat("sergeant", "From today you two bunk together, drill together, and march together. Start by knocking each other about."),
		Cutscenes.beat("sergeant", "One bout, in the yard. He's learned spike up: when he plants his point and shouts, get clear or get thrown."),
		Cutscenes.beat("darren", "Don't worry. I'll go easy on you."),
		Cutscenes.beat("", "He will not go easy on you."),
	]
	return {"id": "bootcamp_darren", "setting": "yard", "place": "The drill yard", "beats": beats,
			"cast": [_you(you, 0.28), Cutscenes.actor("sergeant", SERGEANT_LOOK, 0.5, 44),
				Cutscenes.actor("darren", DARREN_LOOK, 0.9, 42)]}


## After the bout: won, he sees your potential; lost, he tells you what to
## fix, and can't wait to work with you.
static func _bout_over(you: Dictionary, won: bool) -> Dictionary:
	var beats: Array
	if won:
		beats = [
			Cutscenes.beat("", "Darren goes down in the straw and stays there a moment, looking at the sky."),
			Cutscenes.beat("darren", "...Huh."),
			Cutscenes.beat("darren", "Nobody gets past the spike on their first bout. I didn't. I ate it twice."),
			Cutscenes.beat("sergeant", "Well, well. Up you get, Heroldt. You're embarrassing the straw."),
			Cutscenes.beat("darren", "You've got something, recruit. A real point on you.", [Cutscenes.on("hop", "darren")]),
			Cutscenes.beat("darren", "I'm going to have to work to keep up with you. Good. I'll be watching."),
		]
	else:
		beats = [
			Cutscenes.beat("", "The yard tips over. For a moment you are looking at the sky."),
			Cutscenes.beat("darren", "Got you on the landing! Everyone eats the spike the first time. I ate it twice."),
			Cutscenes.beat("darren", "You came at me flat. Lead with your point. And when I plant and shout, roll out wide. Don't jump: that's what I want."),
			Cutscenes.beat("darren", "You hit hard, though. Hard, for a first bout."),
			Cutscenes.beat("sergeant", "Constructive, Heroldt. I'm moved. On your feet, recruit."),
			Cutscenes.beat("darren", "We're going to make a good pair, you and me. I can tell.", [Cutscenes.on("hop", "darren")]),
		]
	beats.append(Cutscenes.beat("sergeant", "Don't let it go to your head, recruit. You're only getting started."))
	beats.append(Cutscenes.beat("sergeant", "Keep at your training: the straw, the recruits, Heroldt here. When you feel ready for real combat, see the General for deployment. His tent is west."))
	return {"id": "bootcamp_bout_" + ("won" if won else "lost"), "setting": "yard", "place": "The drill yard",
			"beats": beats,
			"cast": [_you(you, 0.3), Cutscenes.actor("sergeant", SERGEANT_LOOK, 0.52, 44),
				Cutscenes.actor("darren", DARREN_LOOK, 0.72, 42)]}
