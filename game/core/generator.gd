class_name PieceGenerator
extends RefCounted
## Draws trays of three wall pieces for Classic runs.
##
## Fairness, like block puzzles that feel fair: every fresh tray contains at least
## one piece that fits somewhere on the board when any piece can fit at all. It is
## only a floor: the other two pieces are drawn normally, so a crowded board still
## means trouble. Awkward pieces get likelier as the run's score rises.

const TRAY: int = 3
const REROLLS: int = 6
## Score at which the draw reaches full difficulty.
const FULL_DIFFICULTY_SCORE: float = 40000.0


## 0 at the start of a run, 1 at FULL_DIFFICULTY_SCORE, rising fastest early on
## (scores grow quickly once big pens start closing).
static func difficulty_for(score: int) -> float:
	return clampf(log(1.0 + float(score) / 1000.0) / log(1.0 + FULL_DIFFICULTY_SCORE / 1000.0), 0.0, 1.0)


static func draw_one(rng: Rng, difficulty: float) -> String:
	return str(rng.weighted(Pieces.weights(difficulty)))


static func draw_tray(field: Field, rng: Rng, difficulty: float) -> Array[String]:
	var tray: Array[String] = []
	for attempt: int in REROLLS + 1:
		tray.clear()
		for k: int in TRAY:
			tray.append(draw_one(rng, difficulty))
		for p: String in tray:
			if field.fits_anywhere(p):
				return tray
	# Nothing drawn fits: swap one slot for a piece that does, friendliest classes
	# first, picked at random inside the class so it isn't always a dot.
	for cls: String in ["easy", "small", "medium", "awkward"]:
		var options: Array = (Pieces.CLASSES[cls] as Array).duplicate()
		rng.shuffle(options)
		for p: String in options:
			if field.fits_anywhere(p):
				tray[rng.range_i(0, TRAY - 1)] = p
				return tray
	return tray
