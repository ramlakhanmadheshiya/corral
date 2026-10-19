class_name LevelMaker
extends RefCounted
## Shared layout helpers for daily boards and challenge levels: scatters rocks,
## gems and a few starting wall fragments without sealing any region.


## Adds rocks anywhere, gems away from the edge, and short wall fragments, never
## leaving an enclosed region (which would be a free capture on move one).
static func scatter(f: Field, rng: Rng, rocks: int, gems: int, fragments: int) -> void:
	for k: int in rocks:
		_place_safe(f, rng, Field.ROCK, false)
	for k: int in fragments:
		var piece: String = str(rng.pick(["i2h", "i2v", "i3h", "i3v", "c1", "c2", "c3", "c4"]))
		var spots: Array = f.placements(piece)
		rng.shuffle(spots)
		for o: Variant in spots:
			var cov: PackedInt32Array = Field.cover(piece, o)
			for i: int in cov:
				f.cells[i] = Field.WALL
			if f.enclosed_regions().is_empty():
				break
			for i: int in cov:
				f.cells[i] = Field.EMPTY
	for k: int in gems:
		var options: Array = []
		for i: int in Field.N * Field.N:
			if f.is_free(i) and not Field.is_border(i):
				options.append(i)
		if options.is_empty():
			break
		f.gems[int(rng.pick(options))] = 1


static func _place_safe(f: Field, rng: Rng, kind: int, inner_only: bool) -> void:
	var options: Array = []
	for i: int in Field.N * Field.N:
		if f.is_free(i) and (not inner_only or not Field.is_border(i)):
			options.append(i)
	rng.shuffle(options)
	for c: Variant in options:
		f.cells[int(c)] = kind
		if f.enclosed_regions().is_empty():
			return
		f.cells[int(c)] = Field.EMPTY


# --- Challenge levels ------------------------------------------------------------

## Longest piece sequence a challenge is generated with (the stored level is cut
## down to what the goal needs plus some spare).
const MAX_SEQUENCE: int = 45
const CANDIDATES: int = 5
const ATTEMPTS: int = 60


## The goal's target for level n (1-based) of chapter c.
static func goal_target(kind: String, c: int, n: int, per_chapter: int, gems_on_board: int) -> int:
	var t: float = float(n - 1) / float(maxi(1, per_chapter - 1))
	match kind:
		"captures":
			return 2 + int(round(t * 4.0)) + c / 3
		"pen":
			return clampi(int(round(2.0 + t * (6.0 + 1.4 * c))), 2, 16)
		"gems":
			return clampi(1 + int(round(t * 2.0)) + c / 4, 1, maxi(1, gems_on_board))
		"score":
			return int(round((250.0 + t * 1500.0) * (1.0 + 0.45 * c) / 50.0)) * 50
		"combo":
			return 1 if t < 0.6 else 2
	return 1


## Builds level n of a chapter: tries seeded layouts and sequences, lets the bot
## play each, keeps the candidates it can win, and picks the one whose length
## best matches the chapter's difficulty curve. Deterministic.
static func challenge(plan: Dictionary, c: int, n: int, per_chapter: int) -> Dictionary:
	var kind: String = str((plan["goals"] as Array)[n - 1])
	var t: float = float(n - 1) / float(maxi(1, per_chapter - 1))
	var moves: Array = plan.get("moves", [3, 12])
	var want: int = int(round(lerpf(float(moves[0]), float(moves[1]), t)))
	var diff: Array = plan.get("difficulty", [0.2, 0.5])
	var d: float = lerpf(float(diff[0]), float(diff[1]), t)
	var best: Dictionary = {}
	var best_gap: int = 1 << 30
	var found: int = 0
	for attempt: int in ATTEMPTS:
		var rng: Rng = Rng.new(Rng.hash_string("corral-%s-%d-%d" % [plan["id"], n, attempt]))
		var f: Field = Field.new()
		var rocks: Array = plan.get("rocks", [0, 0])
		var gems: Array = plan.get("gems", [0, 0])
		var frags: Array = plan.get("fragments", [0, 2])
		var gem_n: int = rng.range_i(int(gems[0]), int(gems[1]))
		if kind == "gems":
			gem_n = maxi(gem_n, 2)
		var seq: Array = []
		for k: int in MAX_SEQUENCE:
			seq.append(PieceGenerator.draw_one(rng, d))
		if kind == "combo":
			_twin_pens(f, rng, seq)
		scatter(f, rng, rng.range_i(int(rocks[0]), int(rocks[1])), gem_n, rng.range_i(int(frags[0]), int(frags[1])))
		var target: int = goal_target(kind, c, n, per_chapter, f.gem_count())
		if kind == "gems" and f.gem_count() < target:
			continue
		var level: Dictionary = f.to_dict()
		level["id"] = "%s-%02d" % [plan["id"], n]
		level["goal"] = {"type": kind, "target": target}
		level["hop"] = bool(plan.get("hop", false))
		level["sequence"] = seq
		var run: Dictionary = CorralBot.play(RunState.from_level(level), MAX_SEQUENCE)
		var end: RunState = run["state"]
		if not end.goal_met():
			continue
		var k: int = end.placed
		# A goal met on the first move or two is no puzzle at all.
		if k < (3 if kind == "combo" else 2):
			continue
		var pieces: int = mini(MAX_SEQUENCE, maxi(k + 3, k + int(ceil(k * 0.6))))
		level["sequence"] = seq.slice(0, pieces)
		level["pieces"] = pieces
		level["par"] = [mini(pieces, k + maxi(1, k / 5)), mini(pieces, k + maxi(2, k / 2))]
		level["solution"] = run["moves"]
		level["bot_moves"] = k
		var gap: int = absi(k - want)
		if gap < best_gap:
			best_gap = gap
			best = level
		found += 1
		if found >= CANDIDATES or gap == 0:
			break
	return best


## Two one-cell pens, each missing one wall, whose gaps a single straight piece
## closes together (a guaranteed combo); that piece goes early in the sequence.
static func _twin_pens(f: Field, rng: Rng, seq: Array) -> void:
	var vertical: bool = rng.chance(0.5)
	var x: int = rng.range_i(2, 5 if vertical else 5)
	var y: int = rng.range_i(2, 4 if vertical else 6)
	var walls: Array = []
	if vertical:
		# Pens at (x, y) and (x, y + 2); the gaps are both on the left, closed by i3v.
		walls = [Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1), Vector2i(x + 1, y + 2), Vector2i(x, y + 3)]
		seq[rng.range_i(4, 8)] = "i3v"
	else:
		# Pens at (x, y) and (x + 2, y); the gaps are both above, closed by i3h.
		walls = [Vector2i(x, y + 1), Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x + 2, y + 1), Vector2i(x + 3, y)]
		seq[rng.range_i(4, 8)] = "i3h"
	for w: Vector2i in walls:
		if w.x >= 0 and w.y >= 0 and w.x < Field.N and w.y < Field.N:
			f.cells[Field.idx(w.x, w.y)] = Field.WALL
