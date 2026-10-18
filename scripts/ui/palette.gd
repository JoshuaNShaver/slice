class_name Palette
## Chalk pastels on parchment, outlined in sepia ink (design log 0014).

const PARCHMENT := Color("efe3c8")
const PARCHMENT_LIGHT := Color("f7efdc")
const PARCHMENT_DARK := Color("ddcba4")
const INK := Color("3b2a1e")
const INK_FADED := Color(0.23, 0.16, 0.12, 0.45)
const INK_STAIN := Color(0.23, 0.16, 0.12, 0.07)

# Bars: deeper chalk so they read against parchment.
const HEALTH := Color("d97b7b")
const ENERGY := Color("7aaed6")
const XP := Color("e0c36a")

## Shapes are plain (design log 0069): an uncoloured fill, as the law against
## colour requires. Colour comes from the underworld and the Colour Revolt.
const PLAIN := PARCHMENT_LIGHT
## The Colour Revolt's loud paint (design log 0068): nothing else is this bright.
const REVOLT := Color("e0452b")

const CHALK: Array[Color] = [
	Color("f4b6b6"),  # rose
	Color("f7cfa1"),  # peach
	Color("f3e6a2"),  # butter
	Color("bfe3b4"),  # mint
	Color("aed4ec"),  # sky
	Color("cdbbe8"),  # lilac
]


static func chalk_for_sides(sides: int) -> Color:
	return CHALK[(sides - 3) % CHALK.size()]


# The underworld: chalk on slate (design log 0056). The ground and the ink
# swap; pastel fills stay the same.
const SLATE := Color("3d4148")
const SLATE_DARK := Color("2b2e34")
const SLATE_LIGHT := Color("50555e")
const CHALK_LINE := Color("ece6d6")
const CHALK_FADED := Color(0.93, 0.9, 0.84, 0.5)
const CHALK_DUST := Color(0.93, 0.9, 0.84, 0.06)


## Ink for text and lines drawn at a world position: sepia above ground,
## chalk in the underworld.
static func ink_at(pos: Vector2) -> Color:
	return CHALK_LINE if Regions.is_underworld(pos) else INK


static func faded_at(pos: Vector2) -> Color:
	return CHALK_FADED if Regions.is_underworld(pos) else INK_FADED
