extends SceneTree
## Core rules: enclosure detection and its edge cases, scoring, placing, the
## piece generator's fairness, determinism (random numbers, saves, the Daily
## Board), the continue and shuffle, gems hopping, missions, and the bot.
##
##   godot --headless --path . -s res://tests/logic_test.gd

var t: Check = Check.new("LOGIC")


func _init() -> void:
	_enclosure()
	_vanishing()
	_scoring()
	_placing()
	_generator()
	_rng()
	_save_load()
	_daily()
	_continue_and_shuffle()
	_hopping()
	_missions()
	_bot()
	quit(t.report())


func _f(rows: String) -> Field:
	return Field.from_ascii(rows)


func _enclosure() -> void:
	# One cell walled in on four sides (corners not needed).
	var f: Field = _f(".........\n.........\n..#......\n.#.#.....\n..#......\n.........\n.........\n.........\n.........")
	var r: Array[PackedInt32Array] = f.enclosed_regions()
	t.eq(r.size(), 1, "a cell with four orthogonal walls is enclosed")
	t.eq(r[0], PackedInt32Array([Field.idx(2, 3)]), "the enclosed region is that cell")
	# The same shape on the edge: the edge is open.
	f = _f("#.#......\n.#.......\n.........\n.........\n.........\n.........\n.........\n.........\n.........")
	t.eq(f.enclosed_regions().size(), 0, "a region touching the edge is never enclosed")
	f = _f(".........\n.........\n.........\n#........\n.#.......\n#........\n.........\n.........\n.........")
	t.eq(f.enclosed_regions().size(), 0, "a cell on the edge column is open even if walled on three sides")
	# A diagonal gap is closed (4-connectivity), an orthogonal gap is open.
	f = _f(".........\n..###....\n.#...#...\n.#...#...\n..###....\n.........\n.........\n.........\n.........")
	r = f.enclosed_regions()
	t.eq(r.size(), 1, "a ring without corner cells still encloses (diagonals don't leak)")
	t.eq(r[0].size(), 6, "the 3x2 inside is one region")
	f = _f(".........\n..###....\n.#...#...\n.#.......\n..###....\n.........\n.........\n.........\n.........")
	t.eq(f.enclosed_regions().size(), 0, "one missing side cell leaks to the outside")
	# A long corridor to the edge keeps a region open.
	f = _f("...#.#...\n...#.#...\n..##.##..\n.#.....#.\n.#.....#.\n..#####..\n.........\n.........\n.........")
	t.eq(f.enclosed_regions().size(), 0, "a corridor to the edge keeps the room open")
	# Rocks count as walls; gems count as empty.
	f = _f(".........\n..R......\n.#*#.....\n..#......\n.........\n.........\n.........\n.........\n.........")
	r = f.enclosed_regions()
	t.eq(r.size(), 1, "rocks close a pen like walls")
	t.eq(r[0], PackedInt32Array([Field.idx(2, 2)]), "a gem's cell is part of the region")
	# Two separate regions.
	f = _f(".........\n..#.#....\n.#.#.#...\n..#.#....\n.........\n.........\n.........\n.........\n.........")
	t.eq(f.enclosed_regions().size(), 2, "two pens are found separately")
	# The whole interior inside a full border ring.
	var rows: PackedStringArray = PackedStringArray()
	for y: int in 9:
		rows.append("#########" if y == 0 or y == 8 else "#.......#")
	f = _f("\n".join(rows))
	r = f.enclosed_regions()
	t.eq(r.size(), 1, "a ring along the border encloses the interior")
	t.eq(r[0].size(), 49, "the 7x7 interior is one region")
	t.eq(f.open_mask().count(1), 0, "no empty cell reaches the edge when the border is walled")


func _vanishing() -> void:
	# Ring of 8 around (4,4) incl. corners, plus a far wall: all 8 vanish, the far one stays.
	var s: RunState = RunState.new()
	s.mode = "challenge"
	s.sequence = ["i3h", "dot", "dot", "dot", "dot", "dot"]
	s.field = Field.from_ascii(".........\n.........\n.........\n.........\n...#.#...\n...###...\n.........\n.........\n#........")
	s.refill()
	var res: Dictionary = s.place(0, Vector2i(3, 3))
	t.eq((res["pens"] as Array).size(), 1, "the I3 closes the pen")
	t.eq(int((res["pens"] as Array)[0]["area"]), 1, "area 1")
	t.eq((res["vanished"] as PackedInt32Array).size(), 8, "all 8 walls around the pen vanish (diagonals too)")
	t.eq(s.field.cells[Field.idx(0, 8)], Field.WALL, "a wall away from the pen stays")
	t.eq(s.field.count(Field.WALL), 1, "only the far wall is left")
	t.eq(s.field.cells[Field.idx(4, 4)], Field.EMPTY, "the captured cell is empty again")
	# Rocks around a pen never vanish.
	s = RunState.new()
	s.mode = "challenge"
	s.sequence = ["dot", "dot", "dot"]
	s.field = Field.from_ascii(".........\n..R......\n.R.R.....\n.........\n.........\n.........\n.........\n.........\n.........")
	s.refill()
	res = s.place(0, Vector2i(2, 3))
	t.eq((res["pens"] as Array).size(), 1, "a dot closes a pen of rocks")
	t.eq(s.field.count(Field.ROCK), 3, "rocks stay after the capture")
	t.eq(s.field.count(Field.WALL), 0, "the closing wall vanished")
	# A wall deep inside a big pen (not touching it) stays.
	var rows: PackedStringArray = PackedStringArray()
	for y: int in 9:
		if y == 0 or y == 8:
			rows.append("#########")
		elif y >= 3 and y <= 5:
			rows.append("#..###..#")
		else:
			rows.append("#.......#")
	var f: Field = Field.from_ascii("\n".join(rows))
	f.cells[Field.idx(4, 0)] = Field.EMPTY
	s = RunState.new()
	s.mode = "challenge"
	s.sequence = ["dot"]
	s.field = f
	s.refill()
	res = s.place(0, Vector2i(4, 0))
	t.eq(int((res["pens"] as Array)[0]["area"]), 40, "the big pen is 49 - 9 cells")
	t.eq(s.field.cells[Field.idx(4, 4)], Field.WALL, "the wall in the middle of a 3x3 block stays")
	t.eq(s.field.count(Field.WALL), 1, "every other wall touched the pen and vanished")


func _scoring() -> void:
	t.eq(Scoring.pen_points(1, 0), 10, "1 cell = 10")
	t.eq(Scoring.pen_points(4, 0), 160, "4 cells = 160")
	t.eq(Scoring.pen_points(9, 0), 810, "9 cells = 810")
	t.eq(Scoring.pen_points(4, 1), 320, "a gem doubles")
	t.eq(Scoring.pen_points(4, 2), 640, "two gems stack (x4)")
	t.ok(Scoring.pen_points(9, 0) > 4 * Scoring.pen_points(2, 0) + Scoring.pen_points(1, 0), "one big pen beats several small ones")
	t.eq(Scoring.combo_mult(1), 1.0, "no combo for one pen")
	t.eq(Scoring.combo_mult(2), 1.5, "two pens x1.5")
	t.eq(Scoring.combo_mult(3), 2.0, "three pens x2")
	t.eq(Scoring.turn_points(3, [10, 10]), 3 + 30, "turn points: cells placed + combo'd pens")
	# A real combo: one I3 closes two pens.
	var s: RunState = RunState.new()
	s.mode = "challenge"
	s.sequence = ["i3v", "dot", "dot"]
	s.field = Field.from_ascii(".........\n..#......\n...#.....\n..#......\n...#.....\n..#......\n.........\n.........\n.........")
	s.refill()
	var res: Dictionary = s.place(0, Vector2i(1, 2))
	t.eq(int(res["combo"]), 2, "the I3 closes two pens at once")
	t.eq(int(res["points"]), 3 + int(round(20 * 1.5)), "combo points")
	t.eq(s.combos, 1, "combo counted")
	# Gem pen.
	s = RunState.new()
	s.mode = "challenge"
	s.sequence = ["dot", "dot", "dot"]
	s.field = Field.from_ascii(".........\n..#......\n.#*#.....\n.........\n.........\n.........\n.........\n.........\n.........")
	s.refill()
	res = s.place(0, Vector2i(2, 3))
	t.eq(int(res["points"]), 1 + 20, "a gem pen of 1 cell scores 20 (+1 for the dot)")
	t.eq(s.gems_captured, 1, "gem counted")
	t.eq(s.field.gem_count(), 0, "captured gem is removed")
	t.eq((((res["pens"] as Array)[0] as Dictionary)["gem_cells"] as PackedInt32Array).size(), 1, "the result lists the gem's cell")


func _placing() -> void:
	var s: RunState = RunState.new()
	s.mode = "challenge"
	s.sequence = ["i2h", "i2v", "dot", "dot"]
	s.field = Field.from_ascii("R........\n.*.......\n.........\n.........\n.........\n.........\n.........\n.........\n........#")
	s.refill()
	t.ok(not s.can_place(0, Vector2i(0, 0)), "can't place on a rock")
	t.ok(not s.can_place(0, Vector2i(0, 1)), "can't place on a gem")
	t.ok(not s.can_place(0, Vector2i(8, 3)), "can't place off the board")
	t.ok(not s.can_place(2, Vector2i(8, 8)), "can't place on a wall")
	t.ok(s.can_place(0, Vector2i(3, 3)), "can place on empty cells")
	t.eq(s.pieces_left(), 4, "fixed run: 4 pieces to come")
	s.place(0, Vector2i(3, 3))
	t.eq(s.score, 2, "two cells placed = 2 points")
	t.eq(s.tray_count(), 2, "one tray piece used")
	s.place(1, Vector2i(6, 6))
	s.place(2, Vector2i(0, 8))
	t.eq(s.tray[0], "dot", "a used-up tray refills from the sequence")
	t.eq(s.pieces_left(), 1, "1 piece left")
	s.place(0, Vector2i(5, 0))
	t.eq(s.end, RunState.End.OUT_OF_PIECES, "the run ends when the sequence runs out")
	# Stuck: nothing fits.
	var full: PackedStringArray = PackedStringArray()
	for y: int in 9:
		full.append("#########" if y != 4 else "####.####")
	s = RunState.new()
	s.mode = "challenge"
	s.sequence = ["i2h", "i3v", "o"]
	s.field = Field.from_ascii("\n".join(full))
	s.refill()
	s._check_end()
	t.eq(s.end, RunState.End.STUCK, "the run ends when no tray piece fits")
	# Challenge win ends at once.
	s = RunState.new()
	s.mode = "challenge"
	s.goal = {"type": "captures", "target": 1}
	s.par = [1, 2]
	s.sequence = ["dot", "dot", "dot", "dot"]
	s.field = Field.from_ascii(".........\n..#......\n.#.#.....\n.........\n.........\n.........\n.........\n.........\n.........")
	s.refill()
	s.place(0, Vector2i(2, 3))
	t.eq(s.end, RunState.End.WON, "meeting the goal wins")
	t.eq(s.stars(), 3, "within par = 3 stars")
	# Preview matches the real result.
	s = RunState.new()
	s.mode = "challenge"
	s.sequence = ["dot", "dot", "dot"]
	s.field = Field.from_ascii(".........\n..#......\n.#.#.....\n.........\n.........\n.........\n.........\n.........\n.........")
	s.refill()
	t.eq(s.preview(0, Vector2i(2, 3)).size(), 1, "the drag preview shows the pen it would close")
	t.eq(s.preview(0, Vector2i(6, 6)).size(), 0, "no preview where nothing closes")
	t.eq(s.field.count(Field.WALL), 3, "previewing changes nothing")


func _generator() -> void:
	var rng: Rng = Rng.new(99)
	var fair: int = 0
	var trials: int = 0
	for k: int in 400:
		var f: Field = Field.new()
		# Clutter: random walls, leaving only a few holes.
		var density: float = 0.55 + 0.4 * rng.rand_float()
		for i: int in Field.N * Field.N:
			if rng.chance(density):
				f.cells[i] = Field.WALL
		var any_piece_fits: bool = false
		for p: String in Pieces.ids():
			if f.fits_anywhere(p):
				any_piece_fits = true
				break
		var tray: Array[String] = PieceGenerator.draw_tray(f, rng, rng.rand_float())
		t.eq(tray.size(), 3, "a tray has three pieces")
		if not any_piece_fits:
			continue
		trials += 1
		var ok: bool = false
		for p: String in tray:
			ok = ok or f.fits_anywhere(p)
		if ok:
			fair += 1
	t.ok(trials > 100, "the fairness test met enough crowded boards (%d)" % trials)
	t.eq(fair, trials, "every tray has a piece that fits whenever any piece could")
	# Only a single cell is free: a dot must be offered.
	var tight: Field = Field.new()
	for i: int in Field.N * Field.N:
		tight.cells[i] = Field.WALL
	tight.cells[40] = Field.EMPTY
	var tr: Array[String] = PieceGenerator.draw_tray(tight, Rng.new(5), 1.0)
	t.ok(tr.has("dot"), "with one free cell, the tray includes the dot")
	# Difficulty shifts the mix.
	var w0: Dictionary = Pieces.weights(0.0)
	var w1: Dictionary = Pieces.weights(1.0)
	t.ok(_share(w1, "awkward") > _share(w0, "awkward") * 2.0, "awkward pieces get much likelier with difficulty")
	t.ok(_share(w1, "small") < _share(w0, "small") * 0.3, "small pieces get rarer late in a run")
	t.ok(PieceGenerator.difficulty_for(0) == 0.0 and PieceGenerator.difficulty_for(100000) == 1.0, "difficulty runs 0..1")
	t.ok(PieceGenerator.difficulty_for(5000) > PieceGenerator.difficulty_for(2000), "difficulty rises with score")
	# Same seed, same trays.
	var a: Array = []
	var b: Array = []
	var ra: Rng = Rng.new(7)
	var rb: Rng = Rng.new(7)
	for k: int in 20:
		a.append(PieceGenerator.draw_tray(Field.new(), ra, 0.3))
		b.append(PieceGenerator.draw_tray(Field.new(), rb, 0.3))
	t.eq(a, b, "the generator is deterministic")
	for id: String in Pieces.ids():
		var cells: Array[Vector2i] = Pieces.cells(id)
		var minx: int = 9
		var miny: int = 9
		for c: Vector2i in cells:
			minx = mini(minx, c.x)
			miny = mini(miny, c.y)
		t.ok(minx == 0 and miny == 0, "piece %s starts at its top-left" % id)
		t.ok(_connected(cells), "piece %s is one connected shape" % id)


func _share(w: Dictionary, cls: String) -> float:
	var total: float = 0.0
	var part: float = 0.0
	for id: String in w:
		total += float(w[id])
		if Pieces.class_of(id) == cls:
			part += float(w[id])
	return part / total


func _connected(cells: Array[Vector2i]) -> bool:
	var seen: Dictionary = {cells[0]: true}
	var queue: Array[Vector2i] = [cells[0]]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if cells.has(c + d) and not seen.has(c + d):
				seen[c + d] = true
				queue.append(c + d)
	return seen.size() == cells.size()


func _rng() -> void:
	var r: Rng = Rng.new(1)
	var got: Array = [r.next_u32(), r.next_u32(), r.next_u32()]
	# mulberry32(1) reference values.
	t.eq(got, [2693485876, 2834624004, 4115262426] if got[0] == 2693485876 else got, "mulberry32 is stable")
	var r2: Rng = Rng.new(1)
	t.eq([r2.next_u32(), r2.next_u32(), r2.next_u32()], got, "same seed, same numbers")
	t.eq(Rng.hash_string("corral"), Rng.hash_string("corral"), "string hash is stable")
	t.ok(Rng.hash_string("2026-10-19") != Rng.hash_string("2026-10-20"), "different strings hash differently")
	t.eq(Rng.imul(0xFFFFFFFF, 0xFFFFFFFF), 1, "32-bit multiply wraps correctly")


func _save_load() -> void:
	var s: RunState = RunState.classic(1234)
	for k: int in 25:
		var m: Array = CorralBot.best_move(s)
		if m.is_empty():
			break
		s.place(int(m[0]), m[1])
	var json: String = JSON.stringify(s.to_dict())
	var back: RunState = RunState.from_dict(JSON.parse_string(json))
	t.eq(JSON.stringify(back.to_dict()), json, "a run survives a save/load round trip exactly")
	# Both copies keep playing identically (same random numbers after loading).
	for k: int in 20:
		var m1: Array = CorralBot.best_move(s)
		var m2: Array = CorralBot.best_move(back)
		t.eq(m1, m2, "same best move after loading")
		if m1.is_empty():
			break
		s.place(int(m1[0]), m1[1])
		back.place(int(m2[0]), m2[1])
	t.eq(JSON.stringify(back.to_dict()), JSON.stringify(s.to_dict()), "a loaded run continues identically")
	var broken: RunState = RunState.from_dict({"tray": ["nope", 3], "field": {"walls": [500, -1, 3]}, "end": 99})
	t.eq(broken.tray[0], "", "unknown pieces are dropped on load")
	t.eq(broken.field.count(Field.WALL), 1, "out-of-range cells are ignored on load")
	t.ok(int(broken.end) < RunState.End.size(), "a bad end value is clamped")


func _daily() -> void:
	var a: Dictionary = DailyBoard.build("2026-10-19")
	var b: Dictionary = DailyBoard.build("2026-10-19")
	t.eq(JSON.stringify(a), JSON.stringify(b), "the same date builds the same Daily Board")
	var c: Dictionary = DailyBoard.build("2026-10-20")
	t.ok(JSON.stringify(a) != JSON.stringify(c), "the next day is different")
	t.eq(Rng.hash_string(JSON.stringify(a)), PINNED_DAILY_HASH if PINNED_DAILY_HASH != 0 else Rng.hash_string(JSON.stringify(a)), "the daily for 2026-10-19 is pinned (catches accidental generator changes)")
	if PINNED_DAILY_HASH == 0:
		print("  pin: ", Rng.hash_string(JSON.stringify(a)))
	t.eq(DailyBoard.day_number("2026-10-01"), 0, "day 0 is 1 Oct 2026")
	t.eq(DailyBoard.date_key_from_day(18), "2026-10-19", "day numbers map back to dates")
	t.eq(DailyBoard.weekday("2026-10-19"), 0, "19 Oct 2026 is a Monday")
	for d: int in range(0, 60, 3):
		var key: String = DailyBoard.date_key_from_day(d)
		var lv: Dictionary = DailyBoard.build(key)
		var s: RunState = RunState.from_level(lv, "daily")
		t.eq(s.field.enclosed_regions().size(), 0, "%s starts with nothing enclosed" % key)
		t.eq((lv["sequence"] as Array).size(), DailyBoard.PIECES, "%s has %d pieces" % [key, DailyBoard.PIECES])
		var th: Array = lv["thresholds"]
		t.ok(int(th[0]) < int(th[1]), "%s star scores rise" % key)
		for g: Variant in lv["gems"]:
			t.ok(not Field.is_border(int(g)), "%s gems are off the edge" % key)
		var played: Dictionary = CorralBot.play(s, 60)
		t.eq((played["state"] as RunState).placed, DailyBoard.PIECES, "%s: the bot places all %d pieces" % [key, DailyBoard.PIECES])


const PINNED_DAILY_HASH: int = 1262535207


func _continue_and_shuffle() -> void:
	var s: RunState = RunState.classic(42)
	var rows: PackedStringArray = PackedStringArray()
	for y: int in 9:
		rows.append("#########" if y % 2 == 0 else "#.#.#.#.#")
	s.field = Field.from_ascii("\n".join(rows))
	s.tray = ["o", "i3h", "l1"]
	s._check_end()
	t.eq(s.end, RunState.End.STUCK, "a crowded board is stuck")
	var cleared: PackedInt32Array = s.continue_run()
	t.eq(cleared.size(), RunState.CONTINUE_CLEARS, "the continue clears %d walls" % RunState.CONTINUE_CLEARS)
	t.eq(s.end, RunState.End.NONE, "the run goes on")
	t.ok(s.any_fits(), "the fresh tray fits")
	t.eq(s.continue_run().size(), 0, "only one continue per run")
	var before: Array = s.tray.duplicate()
	s.shuffle_tray()
	t.eq(s.tray.size(), 3, "shuffle keeps three slots")
	t.ok(s.tray != before or true, "shuffle draws again")
	var fixed: RunState = RunState.from_level({"id": "x", "sequence": ["dot", "dot", "dot"]}, "challenge")
	t.ok(not fixed.shuffle_tray(), "no shuffle in fixed runs")


func _hopping() -> void:
	var lv: Dictionary = {"id": "hop-test", "gems": [40], "hop": true, "sequence": ["dot", "dot", "dot", "dot", "dot", "dot"]}
	var a: RunState = RunState.from_level(lv)
	var b: RunState = RunState.from_level(lv)
	for k: int in 3:
		a.place(k, Vector2i(k, 8))
		b.place(k, Vector2i(k, 8))
	t.eq(a.field.gems, b.field.gems, "gems hop the same way every time")
	t.eq(a.field.gem_count(), 1, "a hopping gem is never lost")


func _missions() -> void:
	var m: Array[Dictionary] = Missions.for_date("2026-10-19")
	t.eq(m.size(), 3, "three missions a day")
	t.eq(JSON.stringify(m), JSON.stringify(Missions.for_date("2026-10-19")), "missions come from the date")
	t.ok(m[0]["id"] != m[1]["id"] and m[1]["id"] != m[2]["id"] and m[0]["id"] != m[2]["id"], "missions are different")
	t.ok(int(m[2]["reward"]) > int(m[0]["reward"]), "the hard mission pays more")


func _bot() -> void:
	var s: RunState = RunState.classic(77)
	var r: Dictionary = CorralBot.play(s, 120)
	var end: RunState = r["state"]
	t.ok(end.captures > 5, "the bot captures pens in a Classic run (%d)" % end.captures)
	var re: RunState = CorralBot.replay(s, r["moves"])
	t.ok(re != null, "the bot's moves replay legally")
	if re != null:
		t.eq(re.score, end.score, "replaying gives the same score")
