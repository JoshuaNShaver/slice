class_name Cutscenes
## What the birth and wedding cutscenes say (design logs 0168, 0171, 0172).
## The server builds them, since content is the server's (log 0101), and
## Net.play_cutscene sends one to a player; the client's CutscenePlayer
## draws it.
##
## A cutscene: {"acts": [act, ...], "wake": [line, ...], "wake_speaker": name}.
## `wake` is said in the world once the overlay closes, by `wake_speaker`
## (an NPC's name, or "" for your own thoughts).
## An act: {"id", "setting", "place", "cast", "beats"}; `place` is a caption.
## - id: names the act for "seen before" (skippable after the first time).
## - setting: "board" (the Board's examining room), "temple", or "below"
##   (the Undercroft, chalk on slate).
## - cast: {role: {"name", "sides", "kind", "apex"}}, roles "priest",
##   "inspector", "father", "mother", "newborn", "groom", "bride". Women
##   (mother, bride) are lines (DESIGN §6).
## - beats: [{"who": role or "" (narration), "text", "cue"}]. Cues:
##   "measure" (calipers on the newborn), "bells" (rejoicing), "light"
##   (a halo: a Circle), "wed" (bride and groom drawn together),
##   "away" (the parents turn away), "dark" (fade to black from here on).
##
## Everything follows the book (Part I §3, §4, §7, §11): ranks and their
## callings, the Equilateral born of Isosceles parents, the Neo-Therapeutic
## Gymnasium, irregulars destroyed. Officials are sincerely pompous, never
## cruel on purpose (log 0172).

const INSPECTOR := {"name": "The Inspector", "sides": 5, "kind": "regular", "apex": 0}
const MOTHER := {"name": "Mother", "sides": 2, "kind": "line", "apex": 0}
const BRIDE := {"name": "The Bride", "sides": 2, "kind": "line", "apex": 0}
const GLEANER := "The Gleaner"
## Isosceles callings by apex (design log 0177).
const WORKMAN_APEX := 45
const TRADE_APEX := 55
## A new family's father: a common Isosceles, a little sharper than his son.
const FOUNDING_FATHER := {"sides": 3, "kind": "isosceles", "apex": 35}

const WAKE_DESTROYED: Array[String] = [
	"Hush. Up there, you died this morning.",
	"The Board sends its 'destroyed' down a chute. I wait at the bottom of it.",
	"This is the Undercroft. The Bonesetter mends us; the cave out west makes fighters of us.",
	"And if anyone up top asks, you're dead. Keep it that way.",
]
const WAKE_FOUNDLING: Array[String] = [
	"You wake on the Center's plaza, a foundling. Up here, no one knows where you came from.",
]


## A new family's first heir: born, and examined by the Board.
## `info`: Net.players' entry (family, sides, kind, apex).
static func founding(info: Dictionary) -> Dictionary:
	var newborn := _shape(info)
	var father := FOUNDING_FATHER.duplicate()
	father.name = "Father"
	var act := _birth_above(newborn, father, info.family, "The Priest", true, false)
	return _with_wake({"acts": [act]}, newborn, false)


## A marriage (PlayerActions.marry): the wedding, then the heir's birth.
## `parent` and `heir` are {sides, kind, apex}; `priest` is who married you.
static func marriage(family: String, parent: Dictionary, heir: Dictionary, priest: String) -> Dictionary:
	var groom := _shape(parent)
	var newborn := _shape(heir)
	var below: bool = parent.kind == "irregular"
	var acts: Array = [_wedding_below(family, groom, priest) if below
			else _wedding(family, groom, priest)]
	var father := groom.duplicate()
	father.name = "Father"
	if below:
		acts.append(_birth_below(newborn, father, family, priest))
	else:
		acts.append(_birth_above(newborn, father, family, priest, false, heir.get("blessed", false)))
	return _with_wake({"acts": acts}, newborn, below)


# --- Weddings ----------------------------------------------------------------

static func _wedding(family: String, groom: Dictionary, priest: String) -> Dictionary:
	var g := groom.duplicate()
	g.name = family
	var beats: Array = [
		_beat("", "Before the Circle, a certificate of marriage is unrolled, signed and sealed."),
		_beat("priest", "%s, %s: your certificate is in order." % [family, _shape_name(groom)]),
		_beat("priest", "Here is your bride: a Woman of good family, who keeps up her peace-cry, and turns her eye upon her husband, and never her back."),
		_beat("bride", "(a soft, steady peace-cry)"),
		_beat("priest", _law_for(groom)),
		_beat("priest", "Before the Circle, I pronounce you wed.", "wed"),
		_beat("priest", "My congratulations, both of you. The Circle is pleased. Now: to the Board, and the nursery."),
	]
	var place := "The Temple of the Circle" if priest == "The High Priest" else "The Center"
	return {"id": "wedding", "setting": "temple", "place": place, "beats": beats,
			"cast": {"priest": _priest(priest), "groom": g, "bride": BRIDE}}


static func _wedding_below(family: String, groom: Dictionary, priest: String) -> Dictionary:
	var g := groom.duplicate()
	g.name = family
	var beats: Array = [
		_beat("", "Under the Undercroft's crooked lamps, a certificate the Circles would never honour is unrolled."),
		_beat("priest", "Good paper. Stolen or earned, I don't ask."),
		_beat("priest", "Your bride. She keeps her peace-cry even down here. Old habits."),
		_beat("bride", "(a soft, steady peace-cry)"),
		_beat("priest", "Upstairs, the law says your son gets a side. Down here the law is: we'll see."),
		_beat("priest", "I was a Circle once, and I can still say the words. You're wed.", "wed"),
		_beat("priest", "Crooked as you came, and together. Congratulations."),
	]
	return {"id": "wedding_below", "setting": "below", "place": "The Undercroft", "beats": beats,
			"cast": {"priest": _priest(priest, true), "groom": g, "bride": BRIDE}}


## The Law of Nature as it applies to this groom (book Part I §3).
static func _law_for(groom: Dictionary) -> String:
	if groom.sides == 3 and groom.kind == "equilateral":
		return "By the Law of Nature, the son of an Equilateral is born a Square. Your house rises today."
	if groom.sides == 3:
		return "By the Law of Nature, the Isosceles son opens his angle a little wider than his father's. Be patient: the Equilateral comes to those who wait."
	return "By the Law of Nature, a son shall have one more side than his father."


# --- Births ----------------------------------------------------------------

## Born above: the Sanitary and Social Board examines the newborn, and the
## priest gives the verdict.
static func _birth_above(newborn: Dictionary, father: Dictionary, family: String, priest: String,
		founding_house: bool, blessed: bool) -> Dictionary:
	var beats: Array = []
	if founding_house:
		beats.append(_beat("", "A son is born, and a house is founded: the house of %s." % family))
	else:
		beats.append(_beat("", "A son is born to the house of %s." % family))
	if blessed:
		beats.append(_beat("", "The certificate was blessed. The Circle has smiled on this house."))
	beats.append(_beat("", "By law, before he is named, he goes before the Sanitary and Social Board."))
	beats.append(_beat("inspector", _measurement(newborn), "measure"))
	var verdict := _verdict(newborn)
	match verdict:
		"irregular":
			beats.append(_beat("inspector", "Deviation: beyond the margin."))
			beats.append(_beat("", "The room goes quiet."))
			beats.append(_beat("priest", "The law is plain. An Irregular is a lie told to every eye that feels him, and a danger to the State."))
			beats.append(_beat("priest", "Let him be destroyed, as the law requires."))
			beats.append(_beat("", "His parents turn away. They do not watch him carried to the chute.", "away"))
			beats.append(_beat("", "Darkness. A long fall.", "dark"))
			beats.append(_beat("", "And then, a voice."))
		"isosceles":
			var short: int = Family.EQUILATERAL_APEX - int(newborn.apex)
			beats.append(_beat("inspector", "Regular, for his class. Certified Isosceles."))
			beats.append(_beat("priest", _isosceles_calling(int(newborn.apex))))
			if short <= Family.APEX_STEP:
				beats.append(_beat("priest", "%d degrees short of the Equilateral. His son may be the one." % short))
			else:
				beats.append(_beat("priest", "%d degrees short of the Equilateral. His son will open a little wider, and his son's son wider still." % short))
			if int(newborn.apex) < TRADE_APEX:
				beats.append(_beat("mother", "(a peace-cry, a little anxious)"))
				beats.append(_beat("priest", "Keep clear of his point, Madam. It is sharp already."))
			else:
				beats.append(_beat("mother", "(a peace-cry, proud)"))
		"equilateral":
			beats.append(_beat("inspector", "...Measured twice. Certified Equilateral."))
			beats.append(_beat("priest", "Let it be proclaimed for many a furlong round: an Equilateral, born of Isosceles stock!", "bells"))
			beats.append(_beat("priest", "He enters the respectable Middle Class: a tradesman. And his son shall be a Square."))
			beats.append(_beat("priest", "By law he is taken this day from his proud yet sorrowing parents, to be raised in a childless Equilateral house, and never to return to the lower class.", "away"))
			beats.append(_beat("", "His father's angle is not his any more. His family's name still is."))
		"square":
			beats.append(_beat("inspector", "Certified Square."))
			beats.append(_beat("priest", "A Square! The house of %s rises out of the Middle Class into the Professions." % family, "bells"))
			beats.append(_beat("priest", "A lawyer, a physician, a gentleman. And a house in the Noble Quarter, with chests of its own."))
		"pentagon":
			beats.append(_beat("inspector", "Certified Pentagon."))
			beats.append(_beat("priest", "A Pentagon: a gentleman of the Professions, like his father, and one side more."))
			beats.append(_beat("priest", "My congratulations to the house of %s." % family))
		"noble":
			beats.append(_beat("inspector", "No sign of irregularity. Certified %s." % _title(newborn)))
			beats.append(_beat("priest", "A %s! He is born into the Nobility." % _title(newborn), "bells"))
			beats.append(_beat("priest", "Many noble infants go to the Neo-Therapeutic Gymnasium, to have their angles set. Most never come back. This one needs no setting."))
			beats.append(_beat("priest", "Count yourselves fortunate."))
		_:  # circle
			beats.append(_beat("inspector", "Certified... Circular."))
			beats.append(_beat("priest", "He belongs to the Priestly Order: to us.", "light"))
			beats.append(_beat("priest", "Bow to him, parents. He already outranks you both."))
	var mother := MOTHER.duplicate()
	return {"id": "birth_" + verdict, "setting": "board", "place": "The Sanitary and Social Board",
			"beats": beats,
			"cast": {"priest": _priest(priest), "inspector": INSPECTOR, "father": father,
				"mother": mother, "newborn": newborn}}


## An Isosceles's calling by his apex (design log 0177): a soldier at the
## sharpest, a workman from 45°, fit for trade from 55°.
static func _isosceles_calling(apex_deg: int) -> String:
	if apex_deg >= TRADE_APEX:
		return "An Isosceles, so nearly regular. Fit for trade: he may keep a booth among the tradesmen, and fight when he is called."
	if apex_deg >= WORKMAN_APEX:
		return "An Isosceles. A workman: the State needs timber and ore, and soldiers when it calls."
	return "An Isosceles, and a sharp one. A soldier: the State has need of points."


## Born below: no Board, just the Hedge Priest.
static func _birth_below(newborn: Dictionary, father: Dictionary, family: String, priest: String) -> Dictionary:
	var beats: Array = [_beat("", "A son is born to the house of %s, far below the Board's notice." % family)]
	beats.append(_beat("priest", _measurement(newborn), "measure"))
	if newborn.kind == "irregular":
		beats.append(_beat("priest", "Crooked, like his father. No one's sending this one down a chute: he's already at the bottom."))
		beats.append(_beat("priest", "Welcome home, little one."))
	else:
		beats.append(_beat("priest", "Regular. True as a Circle's own.", "light"))
		beats.append(_beat("priest", "He can't stay. A regular among us, and they'd come looking for the rest of us."))
		beats.append(_beat("", "That night the Gleaner climbs the chute, and leaves a foundling on the Board's doorstep.", "away"))
		beats.append(_beat("", "Darkness.", "dark"))
	return {"id": "birth_below_" + ("irregular" if newborn.kind == "irregular" else "regular"),
			"setting": "below", "place": "The Undercroft", "beats": beats,
			"cast": {"priest": _priest(priest, true), "father": father, "mother": MOTHER.duplicate(),
				"newborn": newborn}}


## What the inspector reads off the calipers.
static func _measurement(s: Dictionary) -> String:
	var n: int = s.sides
	if n == 3:
		match s.kind:
			"equilateral":
				return "Three sides, all equal. Sixty degrees. Sixty. And sixty."
			"isosceles":
				var base := (180 - int(s.apex)) / 2.0
				return "Three sides, two of them equal. Apex angle: %d degrees; base angles %s and %s." % [
						s.apex, _degrees(base), _degrees(base)]
			_:
				return "Three sides. Apex angle %d degrees, and set off-centre. The base angles disagree." % s.apex
	if s.kind == "irregular":
		return "%s sides, and no two of them agree." % _number(n).capitalize()
	if n >= Family.PRIEST_SIDES:
		return "%s sides, so many and so small the eye cannot tell him from a Circle." % _number(n).capitalize()
	return "%s sides, all equal. Every angle %s degrees." % [_number(n).capitalize(), _degrees(180.0 * (n - 2) / n)]


## "isosceles", "equilateral", "square", "pentagon", "noble", "circle" or
## "irregular": which verdict the Board gives (and which act id).
static func _verdict(s: Dictionary) -> String:
	if s.kind == "irregular":
		return "irregular"
	if s.sides == 3:
		return s.kind
	if s.sides == 4:
		return "square"
	if s.sides == 5:
		return "pentagon"
	return "noble" if s.sides < Family.PRIEST_SIDES else "circle"


static func _with_wake(scene: Dictionary, newborn: Dictionary, below: bool) -> Dictionary:
	if newborn.kind == "irregular" and not below:
		scene.wake = WAKE_DESTROYED
		scene.wake_speaker = GLEANER
	elif below and newborn.kind != "irregular":
		scene.wake = WAKE_FOUNDLING
		scene.wake_speaker = ""
	return scene


static func _beat(who: String, text: String, cue := "") -> Dictionary:
	return {"who": who, "text": text, "cue": cue}


static func _priest(priest_name: String, irregular := false) -> Dictionary:
	return {"name": priest_name, "sides": 11 if irregular else 40,
			"kind": "irregular" if irregular else "regular", "apex": 0}


static func _shape(s: Dictionary) -> Dictionary:
	return {"name": "", "sides": int(s.sides), "kind": str(s.kind), "apex": int(s.get("apex", 0))}


## As a priest would say it: "an isosceles triangle, fifty degrees at the apex".
static func _shape_name(s: Dictionary) -> String:
	var named := Family.with_article(Family.describe_shape(s.sides, s.kind))
	if s.sides == 3 and int(s.apex) > 0 and s.kind != "equilateral":
		named += ", %s degrees at the apex" % _number(int(s.apex))
	return named


static func _title(s: Dictionary) -> String:
	return (Family.POLYGON_NAMES.get(s.sides, "%d-gon" % s.sides) as String).capitalize()


static func _degrees(d: float) -> String:
	return str(int(d)) if is_equal_approx(d, roundf(d)) else "%.1f" % d


## Spelled out up to ninety-nine, as speech.
static func _number(n: int) -> String:
	const ONES := ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
			"ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
			"eighteen", "nineteen"]
	const TENS := ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
	if n < ONES.size():
		return ONES[n]
	if n >= 100:
		return str(n)
	@warning_ignore("integer_division")
	var tens: String = TENS[n / 10]
	return tens if n % 10 == 0 else "%s-%s" % [tens, ONES[n % 10]]
