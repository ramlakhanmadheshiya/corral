class_name Scoring
extends RefCounted
## How a placement scores. A captured pen is worth its area squared times
## CAPTURE_UNIT, so one big pen beats several small ones; each gem inside doubles
## that pen (stacking); closing two or more pens with one piece multiplies the lot.

const CAPTURE_UNIT: int = 10
const PLACE_POINT: int = 1
## Extra multiplier per additional pen closed by the same piece (2 pens = x1.5, 3 = x2).
const COMBO_STEP: float = 0.5
const GEM_MULT: int = 2


static func pen_points(area: int, gems: int) -> int:
	return area * area * CAPTURE_UNIT * int(pow(GEM_MULT, gems))


static func combo_mult(pens: int) -> float:
	return 1.0 + COMBO_STEP * float(maxi(0, pens - 1))


## Points for one placement: the cells placed plus every pen it closed.
static func turn_points(cells_placed: int, pen_values: Array) -> int:
	var caught: int = 0
	for v: Variant in pen_values:
		caught += int(v)
	return cells_placed * PLACE_POINT + int(round(float(caught) * combo_mult(pen_values.size())))
