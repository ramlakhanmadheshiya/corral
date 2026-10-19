class_name CorralBot
extends RefCounted
## A simple planning player. It picks a target pen (a rectangle whose walls are
## nearly built and that suits the goal), then places pieces to finish its walls,
## parking awkward pieces where they do least harm. Used for in-game hints, to
## check that every challenge goal and daily board can be achieved, and in tests.

## How strongly the bot prefers nearly finished pens over big ones.
const GREED: float = 2.2
const MAX_SIDE: int = 5


## Every rectangle the bot could aim to enclose, and how attractive it is now.
static func choose_target(field: Field, goal: Dictionary = {}, greed: float = GREED) -> Dictionary:
	var kind: String = str(goal.get("type", "score"))
	var target: int = int(goal.get("target", 0))
	var best: Dictionary = {}
	var best_p: float = -1.0
	var n: int = Field.N
	for h: int in range(1, MAX_SIDE + 1):
		for w: int in range(1, MAX_SIDE + 1):
			if kind == "pen" and w * h < target:
				continue
			for y0: int in range(1, n - h):
				for x0: int in range(1, n - w):
					var p: Dictionary = _rate(field, x0, y0, w, h, kind, greed)
					if not p.is_empty() and float(p["priority"]) > best_p:
						best_p = float(p["priority"])
						best = p
	return best


static func _rate(field: Field, x0: int, y0: int, w: int, h: int, kind: String, greed: float) -> Dictionary:
	var n: int = Field.N
	var inner: PackedInt32Array = PackedInt32Array()
	var walls_in: int = 0
	var gems: int = 0
	for y: int in range(y0, y0 + h):
		for x: int in range(x0, x0 + w):
			var i: int = y * n + x
			var c: int = field.cells[i]
			if c == Field.ROCK:
				return {}
			if c == Field.WALL:
				walls_in += 1
			gems += field.gems[i]
			inner.append(i)
	var ring: PackedInt32Array = PackedInt32Array()
	for x: int in range(x0, x0 + w):
		ring.append((y0 - 1) * n + x)
		ring.append((y0 + h) * n + x)
	for y: int in range(y0, y0 + h):
		ring.append(y * n + x0 - 1)
		ring.append(y * n + x0 + w)
	var missing: int = 0
	for i: int in ring:
		if field.gems[i] != 0:
			return {}
		if field.cells[i] == Field.EMPTY:
			missing += 1
	var area: int = w * h - walls_in
	if area <= 0:
		return {}
	var value: float
	match kind:
		"gems":
			value = pow(5.0, gems) if gems > 0 else 0.2
		"captures", "combo":
			value = 4.0 / float(area)
		"pen":
			value = 1.0 + 0.1 * gems
		_:
			value = float(Scoring.pen_points(area, gems))
	var priority: float = value / pow(float(missing) + 1.0, greed) - 0.2 * walls_in
	return {"inner": inner, "ring": ring, "missing": missing, "priority": priority, "area": area}


## Rates one placement. Higher is better.
static func rate_move(s: RunState, slot: int, origin: Vector2i, plan: Dictionary) -> float:
	var piece: String = s.tray[slot]
	var cov: PackedInt32Array = Field.cover(piece, origin)
	var f: Field = s.field.clone()
	for i: int in cov:
		f.cells[i] = Field.WALL
	var regions: Array[PackedInt32Array] = f.enclosed_regions()
	var values: Array = []
	var gems: int = 0
	var biggest: int = 0
	for r: PackedInt32Array in regions:
		var g: int = 0
		for i: int in r:
			g += f.gems[i]
		gems += g
		biggest = maxi(biggest, r.size())
		values.append(Scoring.pen_points(r.size(), g))
	var pts: int = Scoring.turn_points(cov.size(), values)
	var v: float = float(pts)
	var kind: String = str(s.goal.get("type", ""))
	match kind:
		"gems":
			v += 4000.0 * gems
		"captures":
			v += 3000.0 * regions.size()
		"combo":
			v += 6000.0 * (1 if regions.size() >= 2 else 0) + 500.0 * regions.size()
		"pen":
			v += 8000.0 if biggest >= int(s.goal.get("target", 0)) else 50.0 * biggest
	if not regions.is_empty():
		for i: int in f.walls_bordering(regions):
			f.cells[i] = Field.EMPTY
	# Building toward the planned pen.
	if not plan.is_empty():
		var ring: PackedInt32Array = plan["ring"]
		var inner: PackedInt32Array = plan["inner"]
		for i: int in cov:
			if ring.has(i):
				v += 40.0
			elif inner.has(i):
				v -= 60.0
	# Keep walls tidy: hug other walls, rocks and the edge rather than splitting open space.
	for i: int in cov:
		var touching: int = 0
		for j: int in Field.orth(i):
			if s.field.cells[j] != Field.EMPTY:
				touching += 1
		if Field.is_border(i):
			touching += 1
		v += 3.0 * touching
	# Never strand the rest of the tray.
	for k: int in RunState.SLOTS:
		if k != slot and not s.tray[k].is_empty() and not f.fits_anywhere(s.tray[k]):
			v -= 5000.0
	v += 2.0 * f.cells.count(Field.EMPTY)
	return v


## The best single move for the current tray, or [] if nothing fits.
static func best_move(s: RunState, greed: float = GREED) -> Array:
	var plan: Dictionary = choose_target(s.field, s.goal, greed)
	var best: Array = []
	var best_v: float = -INF
	var tried: Dictionary = {}
	for slot: int in RunState.SLOTS:
		var piece: String = s.tray[slot]
		if piece.is_empty() or tried.has(piece):
			continue
		tried[piece] = true
		for o: Vector2i in s.field.placements(piece):
			var v: float = rate_move(s, slot, o, plan)
			if v > best_v:
				best_v = v
				best = [slot, o]
	return best


## Plays a run to its end (or `max_moves`). Returns {state, moves: [[slot, x, y]...]}.
static func play(start: RunState, max_moves: int = 400, greed: float = GREED) -> Dictionary:
	var s: RunState = start.clone()
	var moves: Array = []
	while not s.is_over() and moves.size() < max_moves:
		var m: Array = best_move(s, greed)
		if m.is_empty():
			break
		var o: Vector2i = m[1]
		s.place(int(m[0]), o)
		moves.append([int(m[0]), o.x, o.y])
	return {"state": s, "moves": moves}


## Replays recorded moves; returns the final state (or null if a move is illegal).
static func replay(start: RunState, moves: Array) -> RunState:
	var s: RunState = start.clone()
	for m: Variant in moves:
		var a: Array = m
		if not s.can_place(int(a[0]), Vector2i(int(a[1]), int(a[2]))):
			return null
		s.place(int(a[0]), Vector2i(int(a[1]), int(a[2])))
	return s
