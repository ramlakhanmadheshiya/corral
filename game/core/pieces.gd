class_name Pieces
extends RefCounted
## Every wall piece, in fixed orientations (there is no rotation), grouped by how
## easy it is to build pens with. Cells are [x, y] offsets from the top-left.

const SHAPES: Dictionary = {
	"dot": [[0, 0]],
	"i2h": [[0, 0], [1, 0]],
	"i2v": [[0, 0], [0, 1]],
	"i3h": [[0, 0], [1, 0], [2, 0]],
	"i3v": [[0, 0], [0, 1], [0, 2]],
	"i4h": [[0, 0], [1, 0], [2, 0], [3, 0]],
	"i4v": [[0, 0], [0, 1], [0, 2], [0, 3]],
	# Corners: three cells bent once.
	"c1": [[0, 0], [1, 0], [0, 1]],
	"c2": [[0, 0], [1, 0], [1, 1]],
	"c3": [[0, 0], [0, 1], [1, 1]],
	"c4": [[1, 0], [0, 1], [1, 1]],
	# L and J: four cells.
	"l1": [[0, 0], [0, 1], [0, 2], [1, 2]],
	"l2": [[0, 0], [1, 0], [2, 0], [0, 1]],
	"l3": [[0, 0], [1, 0], [1, 1], [1, 2]],
	"l4": [[2, 0], [0, 1], [1, 1], [2, 1]],
	"j1": [[1, 0], [1, 1], [1, 2], [0, 2]],
	"j2": [[0, 0], [0, 1], [1, 1], [2, 1]],
	"j3": [[0, 0], [1, 0], [0, 1], [0, 2]],
	"j4": [[0, 0], [1, 0], [2, 0], [2, 1]],
	# U: a little pen wall, open on one side.
	"u1": [[0, 0], [2, 0], [0, 1], [1, 1], [2, 1]],
	"u2": [[0, 0], [1, 0], [2, 0], [0, 1], [2, 1]],
	"u3": [[0, 0], [1, 0], [0, 1], [0, 2], [1, 2]],
	"u4": [[0, 0], [1, 0], [1, 1], [0, 2], [1, 2]],
	# V: a big ring corner.
	"v1": [[0, 0], [1, 0], [2, 0], [0, 1], [0, 2]],
	"v2": [[0, 0], [1, 0], [2, 0], [2, 1], [2, 2]],
	"v3": [[0, 0], [0, 1], [0, 2], [1, 2], [2, 2]],
	"v4": [[2, 0], [2, 1], [0, 2], [1, 2], [2, 2]],
	# Awkward ones.
	"t1": [[0, 0], [1, 0], [2, 0], [1, 1]],
	"t2": [[1, 0], [0, 1], [1, 1], [2, 1]],
	"t3": [[0, 0], [0, 1], [0, 2], [1, 1]],
	"t4": [[1, 0], [1, 1], [1, 2], [0, 1]],
	"s1": [[1, 0], [2, 0], [0, 1], [1, 1]],
	"s2": [[0, 0], [0, 1], [1, 1], [1, 2]],
	"z1": [[0, 0], [1, 0], [1, 1], [2, 1]],
	"z2": [[1, 0], [0, 1], [1, 1], [0, 2]],
	"o": [[0, 0], [1, 0], [0, 1], [1, 1]],
}

## Classes, from friendliest to most awkward.
const CLASSES: Dictionary = {
	"small": ["dot", "i2h", "i2v"],
	"easy": ["i3h", "i3v", "c1", "c2", "c3", "c4"],
	"medium": ["i4h", "i4v", "l1", "l2", "l3", "l4", "j1", "j2", "j3", "j4", "u1", "u2", "u3", "u4"],
	"awkward": ["v1", "v2", "v3", "v4", "t1", "t2", "t3", "t4", "s1", "s2", "z1", "z2", "o"],
}

static var _cells: Dictionary = {}


static func ids() -> Array:
	return SHAPES.keys()


static func has(id: String) -> bool:
	return SHAPES.has(id)


## Offsets of a piece as Vector2i.
static func cells(id: String) -> Array[Vector2i]:
	if not _cells.has(id):
		var out: Array[Vector2i] = []
		for c: Array in SHAPES.get(id, []):
			out.append(Vector2i(int(c[0]), int(c[1])))
		_cells[id] = out
	return _cells[id]


static func size_of(id: String) -> Vector2i:
	var s: Vector2i = Vector2i.ZERO
	for c: Vector2i in cells(id):
		s = Vector2i(maxi(s.x, c.x + 1), maxi(s.y, c.y + 1))
	return s


static func count(id: String) -> int:
	return SHAPES.get(id, []).size()


static func class_of(id: String) -> String:
	for k: String in CLASSES:
		if (CLASSES[k] as Array).has(id):
			return k
	return "medium"


## Draw weights for a difficulty 0..1: small and friendly pieces fade out, awkward
## ones become likelier as a run goes on.
static func weights(difficulty: float) -> Dictionary:
	var d: float = clampf(difficulty, 0.0, 1.0)
	var share: Dictionary = {
		"small": lerpf(0.16, 0.03, d),
		"easy": lerpf(0.40, 0.24, d),
		"medium": lerpf(0.32, 0.38, d),
		"awkward": lerpf(0.12, 0.35, d),
	}
	var out: Dictionary = {}
	for k: String in CLASSES:
		var members: Array = CLASSES[k]
		for id: String in members:
			out[id] = float(share[k]) / float(members.size())
	# A single dot is a rare gift.
	out["dot"] = float(out["dot"]) * 0.5
	return out
