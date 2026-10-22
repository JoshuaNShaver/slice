class_name Cutscenes
## What the birth and wedding cutscenes say (design logs 0168, 0171, 0172).
## The server builds them, since content is the server's (log 0101), and
## Net.play_cutscene sends one to a player; the client's CutscenePlayer
## draws it. Its header has the format (acts, cast, beats, cues); quests
## build theirs the same way (Quests, log 0179).
##
## Settings used here: "board" (the Board's examining room), "temple",
## "below" (the Undercroft, chalk on slate) and "card"/"card_below" (a
## chronicle's page: some years pass, log 0180). Women (mother, bride) are
## lines (DESIGN §6).
##
## Everything follows the book (Part I §3, §4, §7, §11): ranks and their
## callings, the Equilateral born of Isosceles parents, the Neo-Therapeutic
## Gymnasium, irregulars destroyed. Officials are sincerely pompous, never
## cruel on purpose (log 0172).

const INSPECTOR := {"name": "The Inspector", "sides": 5, "kind": "regular", "apex": 0}
const MOTHER := {"name": "Mother", "look": "line"}
const BRIDE := {"name": "The Bride", "look": "line"}
const GLEANER := "The Gleaner"
## Isosceles callings by apex (design log 0177).
const WORKMAN_APEX := 45
const TRADE_APEX := 55
## A new family's father: a common Isosceles, a little sharper than his son.
const FOUNDING_FATHER := {"sides": 3, "kind": "isosceles", "apex": 35}

const WAKE_DESTROYED: Array[String] = [
	"Look at you, grown. Up there, you died the morning you were born.",
	"The Board sends its 'destroyed' down a chute. I wait at the bottom of it.",
	"This is the Undercroft. The Bonesetter mends us; the cave out west makes fighters of us.",
	"And if anyone up top asks, you're dead. Keep it that way.",
]
const WAKE_FOUNDLING: Array[String] = [
	"You grew up on the Center's plaza, a foundling. Up here, no one knows where you came from.",
]


## A new family's first heir: born, and examined by the Board.
## `info`: Net.players' entry (family, sides, kind, apex).
static func founding(info: Dictionary) -> Dictionary:
	var newborn := _shape(info)
	var father := FOUNDING_FATHER.duplicate()
	father.name = "Father"
	var act := _birth_above(newborn, father, info.family, "The Priest", true, false)
	return _with_wake({"acts": [act, years_pass(newborn, false)]}, newborn, false)


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
	acts.append(years_pass(newborn, below))
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
		_beat("priest", "Before the Circle, I pronounce you wed.", _wed()),
		_beat("priest", "My congratulations, both of you. The Circle is pleased. Now: to the Board, and the nursery."),
	]
	var place := "The Temple of the Circle" if priest == "The High Priest" else "The Center"
	return {"id": "wedding", "setting": "temple", "place": place, "beats": beats,
			"cast": _wedding_cast(_priest(priest), g)}


static func _wedding_below(family: String, groom: Dictionary, priest: String) -> Dictionary:
	var g := groom.duplicate()
	g.name = family
	var beats: Array = [
		_beat("", "Under the Undercroft's crooked lamps, a certificate the Circles would never honour is unrolled."),
		_beat("priest", "Good paper. Stolen or earned, I don't ask."),
		_beat("priest", "Your bride. She keeps her peace-cry even down here. Old habits."),
		_beat("bride", "(a soft, steady peace-cry)"),
		_beat("priest", "Upstairs, the law says your son gets a side. Down here the law is: we'll see."),
		_beat("priest", "I was a Circle once, and I can still say the words. You're wed.", _wed()),
		_beat("priest", "Crooked as you came, and together. Congratulations."),
	]
	return {"id": "wedding_below", "setting": "below", "place": "The Undercroft", "beats": beats,
			"cast": _wedding_cast(_priest(priest, true), g)}


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
	beats.append(_beat("inspector", _measurement(newborn), [_on("measure", "newborn")]))
	var verdict := _verdict(newborn)
	match verdict:
		"irregular":
			beats.append(_beat("inspector", "Deviation: beyond the margin."))
			beats.append(_beat("", "The room goes quiet."))
			beats.append(_beat("priest", "The law is plain. An Irregular is a lie told to every eye that feels him, and a danger to the State."))
			beats.append(_beat("priest", "Let him be destroyed, as the law requires."))
			beats.append(_beat("", "His parents turn away. They do not watch him carried to the chute.", _away()))
			beats.append(_beat("", "Darkness. A long fall.", [{"do": "dark"}]))
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
			beats.append(_beat("priest", "Let it be proclaimed for many a furlong round: an Equilateral, born of Isosceles stock!", [_on("bells", "newborn")]))
			beats.append(_beat("priest", "He enters the respectable Middle Class: a tradesman. And his son shall be a Square."))
			beats.append(_beat("priest", "By law he is taken this day from his proud yet sorrowing parents, to be raised in a childless Equilateral house, and never to return to the lower class.", _away()))
			beats.append(_beat("", "His father's angle is not his any more. His family's name still is."))
		"square":
			beats.append(_beat("inspector", "Certified Square."))
			beats.append(_beat("priest", "A Square! The house of %s rises out of the Middle Class into the Professions." % family, [_on("bells", "newborn")]))
			beats.append(_beat("priest", "A lawyer, a physician, a gentleman. And a house in the Noble Quarter, with chests of its own."))
		"pentagon":
			beats.append(_beat("inspector", "Certified Pentagon."))
			beats.append(_beat("priest", "A Pentagon: a gentleman of the Professions, like his father, and one side more."))
			beats.append(_beat("priest", "My congratulations to the house of %s." % family))
		"noble":
			beats.append(_beat("inspector", "No sign of irregularity. Certified %s." % _title(newborn)))
			beats.append(_beat("priest", "A %s! He is born into the Nobility." % _title(newborn), [_on("bells", "newborn")]))
			beats.append(_beat("priest", "Many noble infants go to the Neo-Therapeutic Gymnasium, to have their angles set. Most never come back. This one needs no setting."))
			beats.append(_beat("priest", "Count yourselves fortunate."))
		_:  # circle
			beats.append(_beat("inspector", "Certified... Circular."))
			beats.append(_beat("priest", "He belongs to the Priestly Order: to us.", [_on("light", "newborn")]))
			beats.append(_beat("priest", "Bow to him, parents. He already outranks you both."))
	var mother := MOTHER
	return {"id": "birth_" + verdict, "setting": "board", "place": "The Sanitary and Social Board",
			"beats": beats,
			"cast": [
				actor("priest", _priest(priest), 0.2, 70), actor("inspector", INSPECTOR, 0.64, 40),
				actor("father", father, 0.8, 40), actor("mother", mother, 0.88, 40),
				actor("newborn", newborn, 0.5, 20, {"cushion": true}),
			]}


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
	beats.append(_beat("priest", _measurement(newborn), [_on("measure", "newborn")]))
	if newborn.kind == "irregular":
		beats.append(_beat("priest", "Crooked, like his father. No one's sending this one down a chute: he's already at the bottom."))
		beats.append(_beat("priest", "Welcome home, little one."))
	else:
		beats.append(_beat("priest", "Regular. True as a Circle's own.", [_on("light", "newborn")]))
		beats.append(_beat("priest", "He can't stay. A regular among us, and they'd come looking for the rest of us."))
		beats.append(_beat("", "That night the Gleaner climbs the chute, and leaves a foundling on the Board's doorstep.", _away()))
		beats.append(_beat("", "Darkness.", [{"do": "dark"}]))
	return {"id": "birth_below_" + ("irregular" if newborn.kind == "irregular" else "regular"),
			"setting": "below", "place": "The Undercroft", "beats": beats,
			"cast": [
				actor("priest", _priest(priest, true), 0.28, 70), actor("father", father, 0.72, 40),
				actor("mother", MOTHER, 0.8, 40), actor("newborn", newborn, 0.5, 20, {"cushion": true}),
			]}


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


# --- Building blocks (quests use these too) --------------------------------

## A beat: `who` (an actor id, or "" for narration) says `text`, and its
## `cues` start (CutscenePlayer).
static func beat(who: String, text: String, cues: Array = []) -> Dictionary:
	return {"who": who, "text": text, "cues": cues}


static func _beat(who: String, text: String, cues: Array = []) -> Dictionary:
	return beat(who, text, cues)


## A cue `what` on actor `who`, with any `more` of its settings.
static func on(what: String, who: String, more := {}) -> Dictionary:
	var cue := {"do": what, "who": who}
	cue.merge(more)
	return cue


static func _on(what: String, who: String, more := {}) -> Dictionary:
	return on(what, who, more)


## An actor for a cast: `look` ({name, sides, kind, apex, look, ...}) standing
## at `x` (0 left, 1 right), `size` px in radius, plus any `more`.
static func actor(id: String, look: Dictionary, x: float, size: float, more := {}) -> Dictionary:
	var a := look.duplicate()
	a.id = id
	a.x = x
	a.size = size
	a.merge(more, true)
	return a


## The parents turn away: they step back and fade.
static func _away() -> Array:
	return [on("move", "father", {"to": 0.86}), on("fade", "father", {"alpha": 0.35}),
			on("move", "mother", {"to": 0.94}), on("fade", "mother", {"alpha": 0.35})]


## Bride and groom drawn together under the Circle.
static func _wed() -> Array:
	return [on("move", "groom", {"to": 0.4}), on("move", "bride", {"to": 0.6}),
			on("join", "groom", {"with": "bride"})]


static func _wedding_cast(priest: Dictionary, groom: Dictionary) -> Array:
	return [actor("priest", priest, 0.5, 70), actor("groom", groom, 0.32, 44), actor("bride", BRIDE, 0.68, 44)]


## Between a birth and play: a chronicle's page, as the book's narrator
## would pass over a childhood (log 0180). The newborn is grown.
static func years_pass(newborn: Dictionary, below: bool) -> Dictionary:
	var beats: Array = []
	if newborn.kind == "irregular":
		beats.append(beat("", "Of a childhood in the Undercroft, the Chronicle can say nothing: officially, there was none."))
		beats.append(beat("", "The Gleaner feeds you. The Bonesetter mends you. The dark teaches you what the Board never would: how to be crooked, and live."))
		beats.append(beat("", "Some years pass. You are grown, and someone is calling you."))
	elif below:
		beats.append(beat("", "A foundling on the Board's doorstep is measured, certified, and given to the State to raise. The State is not a tender parent, but it is a thorough one."))
		beats.append(beat("", "Some years pass. You are grown, and no one up here knows where you came from."))
	else:
		beats.append(beat("", "Of childhood in Flatland there is little worth the reader's patience. It is spent in being measured, and in learning one's place."))
		if newborn.sides == 3 and newborn.kind == "isosceles":
			beats.append(beat("", "The infant grows. His angle sets as it will stay. In the Lower Orders a boy is a man as soon as he can be useful, and the State has many uses for a point."))
		else:
			beats.append(beat("", "The infant grows. His angles set as they will stay. He is schooled, examined, and found to be exactly what the Board said he was."))
		beats.append(beat("", "Some years pass. You are grown."))
	return {"id": "years_pass", "setting": "card_below" if newborn.kind == "irregular" else "card",
			"place": "Some years later", "beats": beats, "cast": []}


## Falling into the western sea (design log 0201): the screen goes dark, and
## you wake on the shore without what you carried. `lost`: how many things.
static func drowned(lost: int) -> Dictionary:
	var beats: Array = [beat("", "The sea closes over you. It is very cold, and very dark, and it does not care what shape you are.")]
	if lost > 0:
		beats.append(beat("", "When it gives you back, it keeps everything you carried."))
	else:
		beats.append(beat("", "When it gives you back, it is almost disappointed: you carried nothing worth keeping."))
	var act := {"id": "drowned", "setting": "card_below", "place": "The western sea", "beats": beats, "cast": []}
	return {"acts": [act], "wake": ["You wake on the shore, coughing up seawater."], "wake_speaker": ""}


static func _priest(priest_name: String, irregular := false) -> Dictionary:
	return {"name": priest_name, "sides": 11 if irregular else 40,
			"kind": "irregular" if irregular else "regular", "apex": 0, "halo": not irregular}


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
