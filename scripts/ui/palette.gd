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
