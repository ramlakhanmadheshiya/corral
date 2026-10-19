class_name Field
extends RefCounted
## The 9 x 9 board as plain data: empty cells, walls the player placed, permanent
## rocks, and gems sitting in empty cells. Knows where pieces fit and which empty
## regions are enclosed.
##
## Enclosure rule: an empty region is captured when none of its cells can reach the
## board edge by stepping up, down, left or right through empty cells. The edge
## itself is open, so a region touching it is never enclosed. Gems sit in empty
## cells and count as empty for this; walls and rocks block.

const N: int = 9
const EMPTY: int = 0
const WALL: int = 1
const ROCK: int = 2

var cells: PackedByteArray = PackedByteArray()
var gems: PackedByteArray = PackedByteArray()

## Orthogonal and 8-way neighbour lists per cell, built once.
static var _orth: Array[PackedInt32Array] = []
static var _ring8: Array[PackedInt32Array] = []
static var _border: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	cells.resize(N * N)
	gems.resize(N * N)
	_build_tables()


static func _build_tables() -> void:
	if not _orth.is_empty():
		return
	for i: int in N * N:
		var x: int = i % N
		var y: int = i / N
		var o: PackedInt32Array = PackedInt32Array()
		var r: PackedInt32Array = PackedInt32Array()
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx: int = x + dx
				var ny: int = y + dy
				if nx < 0 or ny < 0 or nx >= N or ny >= N:
					continue
				r.append(ny * N + nx)
				if dx == 0 or dy == 0:
					o.append(ny * N + nx)
		_orth.append(o)
		_ring8.append(r)
		if x == 0 or y == 0 or x == N - 1 or y == N - 1:
			_border.append(i)


static func idx(x: int, y: int) -> int:
	return y * N + x


static func pos(i: int) -> Vector2i:
	return Vector2i(i % N, i / N)


static func is_border(i: int) -> bool:
	var x: int = i % N
	var y: int = i / N
	return x == 0 or y == 0 or x == N - 1 or y == N - 1


static func orth(i: int) -> PackedInt32Array:
	_build_tables()
	return _orth[i]


static func ring8(i: int) -> PackedInt32Array:
	_build_tables()
	return _ring8[i]


func clone() -> Field:
	var f: Field = Field.new()
	f.cells = cells.duplicate()
	f.gems = gems.duplicate()
	return f


func is_free(i: int) -> bool:
	return cells[i] == EMPTY and gems[i] == 0


func count(kind: int) -> int:
	return cells.count(kind)


func gem_count() -> int:
	return gems.count(1)


## Board cells a piece would cover at `origin` (top-left), or an empty array if
## any of them is off the board.
static func cover(piece: String, origin: Vector2i) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for c: Vector2i in Pieces.cells(piece):
		var x: int = origin.x + c.x
		var y: int = origin.y + c.y
		if x < 0 or y < 0 or x >= N or y >= N:
			return PackedInt32Array()
		out.append(y * N + x)
	return out


func can_place(piece: String, origin: Vector2i) -> bool:
	var cov: PackedInt32Array = cover(piece, origin)
	if cov.is_empty():
		return false
	for i: int in cov:
		if cells[i] != EMPTY or gems[i] != 0:
			return false
	return true


## Every top-left origin where the piece fits.
func placements(piece: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var sz: Vector2i = Pieces.size_of(piece)
	for y: int in N - sz.y + 1:
		for x: int in N - sz.x + 1:
			if can_place(piece, Vector2i(x, y)):
				out.append(Vector2i(x, y))
	return out


func fits_anywhere(piece: String) -> bool:
	if piece.is_empty():
		return false
	var sz: Vector2i = Pieces.size_of(piece)
	for y: int in N - sz.y + 1:
		for x: int in N - sz.x + 1:
			if can_place(piece, Vector2i(x, y)):
				return true
	return false


## Marks every empty cell that can reach the board edge (1) through empty cells.
func open_mask() -> PackedByteArray:
	_build_tables()
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(N * N)
	var queue: PackedInt32Array = PackedInt32Array()
	queue.resize(N * N)
	var head: int = 0
	var tail: int = 0
	for i: int in _border:
		if cells[i] == EMPTY:
			seen[i] = 1
			queue[tail] = i
			tail += 1
	while head < tail:
		var i: int = queue[head]
		head += 1
		for j: int in _orth[i]:
			if seen[j] == 0 and cells[j] == EMPTY:
				seen[j] = 1
				queue[tail] = j
				tail += 1
	return seen


## The enclosed empty regions, each a list of cell indices (4-connected).
func enclosed_regions() -> Array[PackedInt32Array]:
	var seen: PackedByteArray = open_mask()
	var out: Array[PackedInt32Array] = []
	for start: int in N * N:
		if cells[start] != EMPTY or seen[start] != 0:
			continue
		var region: PackedInt32Array = PackedInt32Array([start])
		seen[start] = 1
		var head: int = 0
		while head < region.size():
			var i: int = region[head]
			head += 1
			for j: int in _orth[i]:
				if seen[j] == 0 and cells[j] == EMPTY:
					seen[j] = 1
					region.append(j)
		region.sort()
		out.append(region)
	return out


## Walls (never rocks) touching any cell of the regions, diagonals included.
func walls_bordering(regions: Array[PackedInt32Array]) -> PackedInt32Array:
	var mark: PackedByteArray = PackedByteArray()
	mark.resize(N * N)
	for r: PackedInt32Array in regions:
		for i: int in r:
			for j: int in _ring8[i]:
				if cells[j] == WALL:
					mark[j] = 1
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in N * N:
		if mark[i] == 1:
			out.append(i)
	return out


func to_dict() -> Dictionary:
	var walls: Array = []
	var rocks: Array = []
	var g: Array = []
	for i: int in N * N:
		if cells[i] == WALL:
			walls.append(i)
		elif cells[i] == ROCK:
			rocks.append(i)
		if gems[i] != 0:
			g.append(i)
	return {"walls": walls, "rocks": rocks, "gems": g}


static func from_dict(d: Dictionary) -> Field:
	var f: Field = Field.new()
	for i: Variant in d.get("walls", []):
		if int(i) >= 0 and int(i) < N * N:
			f.cells[int(i)] = WALL
	for i: Variant in d.get("rocks", []):
		if int(i) >= 0 and int(i) < N * N:
			f.cells[int(i)] = ROCK
	for i: Variant in d.get("gems", []):
		if int(i) >= 0 and int(i) < N * N and f.cells[int(i)] == EMPTY:
			f.gems[int(i)] = 1
	return f


## A compact text picture, for tests and debugging ("#" wall, "R" rock, "*" gem).
func ascii() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for y: int in N:
		var s: String = ""
		for x: int in N:
			var i: int = y * N + x
			s += "#" if cells[i] == WALL else ("R" if cells[i] == ROCK else ("*" if gems[i] != 0 else "."))
		lines.append(s)
	return "\n".join(lines)


static func from_ascii(text: String) -> Field:
	var f: Field = Field.new()
	var rows: PackedStringArray = text.strip_edges().split("\n")
	for y: int in mini(N, rows.size()):
		var row: String = rows[y].strip_edges()
		for x: int in mini(N, row.length()):
			var i: int = y * N + x
			match row[x]:
				"#":
					f.cells[i] = WALL
				"R":
					f.cells[i] = ROCK
				"*":
					f.gems[i] = 1
	return f
