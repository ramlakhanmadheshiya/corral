class_name RunState
extends RefCounted
## One game in play: the board, the tray of three pieces, the score and the
## goal. Pure data and rules (no nodes), so tests, the hint bot and the level
## generator all use exactly what the player plays.
##
## Modes:
## - "classic": endless; trays come from PieceGenerator; gems appear, later hop,
##   and rocks arrive as the score climbs.
## - "daily" / "challenge": a fixed layout and a fixed piece sequence, so everyone
##   gets the same game; a challenge also has a goal and ends when it is met.

const SLOTS: int = 3
## Classic: rocks arrive at these scores, then every ROCK_EVERY after the last.
const FIRST_ROCK_AT: int = 3000
const ROCK_EVERY: int = 4000
const MAX_ROCKS: int = 8
const MAX_GEMS: int = 3
const GEM_CHANCE: float = 0.45
## Classic: gems start hopping once the score passes this.
const HOP_FROM_SCORE: int = 6000
const HOP_CHANCE: float = 0.6
## Pen colours cycle through this many palette slots.
const PEN_COLORS: int = 6
## The continue removes up to this many walls, nearest the centre first.
const CONTINUE_CLEARS: int = 14

enum End { NONE, WON, STUCK, OUT_OF_PIECES }

var mode: String = "classic"
var level_id: String = ""
var field: Field = Field.new()
var tray: Array[String] = ["", "", ""]
var rng: Rng = Rng.new(1)
var score: int = 0
var placed: int = 0
var captures: int = 0
var biggest: int = 0
var gems_captured: int = 0
var combos: int = 0
var best_turn: int = 0
var refills: int = 0
var continues: int = 0
var hints: int = 0
var tutorial: bool = false
var end: End = End.NONE
## Fixed-sequence modes.
var sequence: Array[String] = []
var seq_pos: int = 0
var goal: Dictionary = {}
var par: Array = []          # challenge: [pieces for 3 stars, pieces for 2 stars]
var thresholds: Array = []   # daily: [score for 2 stars, score for 3 stars]
var hop: bool = false
var next_rock_at: int = FIRST_ROCK_AT
## Which pen colour last filled each cell (0 = never), for the board's faint
## stains and the share picture.
var stain: PackedByteArray = PackedByteArray()
var pens_total: int = 0


func _init() -> void:
	stain.resize(Field.N * Field.N)


# --- Starting a run ----------------------------------------------------------

static func classic(seed_value: int) -> RunState:
	var s: RunState = RunState.new()
	s.mode = "classic"
	s.rng = Rng.new(seed_value)
	s.refill()
	return s


## The guided first run: a pen with one side missing and a piece that closes it.
static func first_run(seed_value: int) -> RunState:
	var s: RunState = RunState.new()
	s.mode = "classic"
	s.tutorial = true
	s.rng = Rng.new(seed_value)
	s.field = Field.from_ascii(TUTORIAL_BOARD)
	s.tray = ["i2v", "i3h", "c1"]
	return s


const TUTORIAL_BOARD: String = """
.........
.........
...##....
..#......
..#......
...##....
.........
.........
.........
"""
## Where the tutorial's first piece (i2v, slot 0) closes the pen.
const TUTORIAL_TARGET: Vector2i = Vector2i(5, 3)


## A daily board or a challenge level from its data (see Catalog / DailyBoard).
static func from_level(level: Dictionary, kind: String = "challenge") -> RunState:
	var s: RunState = RunState.new()
	s.mode = kind
	s.level_id = str(level.get("id", ""))
	s.field = Field.from_dict(level)
	for p: Variant in level.get("sequence", []):
		if Pieces.has(str(p)):
			s.sequence.append(str(p))
	s.goal = level.get("goal", {})
	s.par = level.get("par", [])
	s.thresholds = level.get("thresholds", [])
	s.hop = bool(level.get("hop", false))
	s.rng = Rng.new(Rng.hash_string(s.level_id))
	s.refill()
	return s


func clone() -> RunState:
	var s: RunState = RunState.from_dict(to_dict())
	return s


# --- Queries -----------------------------------------------------------------

func fixed() -> bool:
	return mode != "classic"


func is_over() -> bool:
	return end != End.NONE


func tray_count() -> int:
	var n: int = 0
	for p: String in tray:
		if not p.is_empty():
			n += 1
	return n


## Pieces still to come in a fixed run (tray + sequence); -1 when endless.
func pieces_left() -> int:
	if not fixed():
		return -1
	return tray_count() + maxi(0, sequence.size() - seq_pos)


func difficulty() -> float:
	return PieceGenerator.difficulty_for(score)


func can_place(slot: int, origin: Vector2i) -> bool:
	if slot < 0 or slot >= SLOTS or tray[slot].is_empty() or is_over():
		return false
	return field.can_place(tray[slot], origin)


func slot_fits(slot: int) -> bool:
	return slot >= 0 and slot < SLOTS and field.fits_anywhere(tray[slot])


func any_fits() -> bool:
	for k: int in SLOTS:
		if slot_fits(k):
			return true
	return false


## What closing this placement would capture, without changing anything
## (the board shows it as a preview while dragging).
func preview(slot: int, origin: Vector2i) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	if not can_place(slot, origin):
		return out
	var f: Field = field.clone()
	for i: int in Field.cover(tray[slot], origin):
		f.cells[i] = Field.WALL
	return f.enclosed_regions()


# --- Goals and stars ---------------------------------------------------------

func goal_value() -> int:
	match str(goal.get("type", "")):
		"score":
			return score
		"pen":
			return biggest
		"captures":
			return captures
		"gems":
			return gems_captured
		"combo":
			return combos
	return 0


func goal_target() -> int:
	return int(goal.get("target", 0))


func goal_met() -> bool:
	return not goal.is_empty() and goal_value() >= goal_target()


## Stars for a finished run: challenges by pieces used, dailies by score.
func stars() -> int:
	if mode == "challenge":
		if not goal_met():
			return 0
		if par.size() >= 2:
			if placed <= int(par[0]):
				return 3
			if placed <= int(par[1]):
				return 2
		return 1
	if mode == "daily":
		if thresholds.size() >= 2:
			if score >= int(thresholds[1]):
				return 3
			if score >= int(thresholds[0]):
				return 2
		return 1
	return 0


# --- Playing -----------------------------------------------------------------

## Places the piece in `slot` with its top-left at `origin` and resolves
## everything that follows. Returns what happened, for the board to animate:
## {ok, slot, piece, cells, pens: [{cells, area, gems, points, color}], combo,
##  points, vanished, refilled, events: [{type, cell, from}], end}
func place(slot: int, origin: Vector2i) -> Dictionary:
	if not can_place(slot, origin):
		return {"ok": false}
	var piece: String = tray[slot]
	var cov: PackedInt32Array = Field.cover(piece, origin)
	for i: int in cov:
		field.cells[i] = Field.WALL
	tray[slot] = ""
	placed += 1
	var regions: Array[PackedInt32Array] = field.enclosed_regions()
	var vanished: PackedInt32Array = field.walls_bordering(regions)
	var pens: Array[Dictionary] = []
	var values: Array = []
	for r: PackedInt32Array in regions:
		var gem_cells: PackedInt32Array = PackedInt32Array()
		for i: int in r:
			if field.gems[i] != 0:
				gem_cells.append(i)
		var g: int = gem_cells.size()
		var pts: int = Scoring.pen_points(r.size(), g)
		pens_total += 1
		var color: int = (pens_total - 1) % PEN_COLORS
		pens.append({"cells": r, "area": r.size(), "gems": g, "gem_cells": gem_cells, "points": pts, "color": color})
		values.append(pts)
		captures += 1
		biggest = maxi(biggest, r.size())
		gems_captured += g
		for i: int in r:
			field.gems[i] = 0
			stain[i] = color + 1
	for i: int in vanished:
		field.cells[i] = Field.EMPTY
	if regions.size() >= 2:
		combos += 1
	var pts_total: int = Scoring.turn_points(cov.size(), values)
	score += pts_total
	best_turn = maxi(best_turn, pts_total)
	var result: Dictionary = {
		"ok": true, "slot": slot, "piece": piece, "origin": origin, "cells": cov, "pens": pens,
		"combo": regions.size(), "points": pts_total, "vanished": vanished,
		"refilled": false, "events": [], "end": End.NONE,
	}
	if mode == "challenge" and goal_met():
		end = End.WON
		result["end"] = end
		return result
	if tray_count() == 0:
		result["events"] = _between_trays()
		refill()
		result["refilled"] = true
	_check_end()
	result["end"] = end
	return result


## Fills an empty tray: from the generator (Classic) or the next pieces of the
## fixed sequence.
func refill() -> void:
	if tray_count() > 0:
		return
	refills += 1
	if fixed():
		for k: int in SLOTS:
			tray[k] = sequence[seq_pos] if seq_pos < sequence.size() else ""
			if seq_pos < sequence.size():
				seq_pos += 1
	else:
		var t: Array[String] = PieceGenerator.draw_tray(field, rng, difficulty())
		for k: int in SLOTS:
			tray[k] = t[k]


func _check_end() -> void:
	if end != End.NONE:
		return
	if tray_count() == 0:
		end = End.OUT_OF_PIECES
	elif not any_fits():
		end = End.STUCK


## Between trays: gems appear and hop, and rocks arrive (Classic); in fixed
## modes only hopping gems move, from the level's own seeded generator.
func _between_trays() -> Array:
	var events: Array = []
	if hop or (not fixed() and score >= HOP_FROM_SCORE):
		events.append_array(_hop_gems())
	if tutorial:
		# The guided first tray is over: the run carries on as a normal Classic run.
		tutorial = false
		return events
	if fixed():
		return events
	if refills >= 2 and field.gem_count() < MAX_GEMS and rng.chance(GEM_CHANCE):
		var c: int = _random_inner_free()
		if c >= 0:
			field.gems[c] = 1
			events.append({"type": "gem", "cell": c})
	if score >= next_rock_at and field.count(Field.ROCK) < MAX_ROCKS:
		var r: int = _safe_rock_cell()
		if r >= 0:
			field.cells[r] = Field.ROCK
			events.append({"type": "rock", "cell": r})
		next_rock_at += ROCK_EVERY
	return events


func _hop_gems() -> Array:
	var events: Array = []
	for i: int in Field.N * Field.N:
		if field.gems[i] == 0 or not rng.chance(HOP_CHANCE):
			continue
		var options: Array = []
		for j: int in Field.orth(i):
			if field.is_free(j) and not Field.is_border(j):
				options.append(j)
		if options.is_empty():
			continue
		var to: int = int(rng.pick(options))
		field.gems[i] = 0
		field.gems[to] = 2  # 2 = moved this turn (so it doesn't hop twice)
		events.append({"type": "hop", "cell": to, "from": i})
	for i: int in Field.N * Field.N:
		if field.gems[i] == 2:
			field.gems[i] = 1
	return events


## A random free cell off the edge (a gem on the edge could never be captured).
func _random_inner_free() -> int:
	var options: Array = []
	for i: int in Field.N * Field.N:
		if field.is_free(i) and not Field.is_border(i):
			options.append(i)
	return int(rng.pick(options)) if not options.is_empty() else -1


## A free cell where a rock doesn't seal off a region by itself.
func _safe_rock_cell() -> int:
	var options: Array = []
	for i: int in Field.N * Field.N:
		if field.is_free(i):
			options.append(i)
	rng.shuffle(options)
	for c: Variant in options:
		field.cells[int(c)] = Field.ROCK
		var sealed: bool = not field.enclosed_regions().is_empty()
		field.cells[int(c)] = Field.EMPTY
		if not sealed:
			return int(c)
	return -1


## Rewarded continue (Classic, once per run): clears the walls nearest the
## centre and deals a fresh tray that fits. Returns the cleared cells.
func continue_run() -> PackedInt32Array:
	var cleared: PackedInt32Array = PackedInt32Array()
	if fixed() or continues > 0 or end != End.STUCK:
		return cleared
	continues += 1
	var walls: Array = []
	for i: int in Field.N * Field.N:
		if field.cells[i] == Field.WALL:
			walls.append(i)
	var c: Vector2 = Vector2(4, 4)
	walls.sort_custom(func(a: int, b: int) -> bool:
		var da: float = Vector2(Field.pos(a)).distance_squared_to(c)
		var db: float = Vector2(Field.pos(b)).distance_squared_to(c)
		return da < db or (da == db and a < b))
	for k: int in mini(CONTINUE_CLEARS, walls.size()):
		field.cells[int(walls[k])] = Field.EMPTY
		cleared.append(int(walls[k]))
	tray = ["", "", ""]
	refill()
	end = End.NONE
	_check_end()
	return cleared


## Shuffle (Classic): swaps the unused pieces for new ones.
func shuffle_tray() -> bool:
	if fixed() or is_over():
		return false
	var t: Array[String] = PieceGenerator.draw_tray(field, rng, difficulty())
	for k: int in SLOTS:
		if not tray[k].is_empty():
			tray[k] = t[k]
	_check_end()
	return true


# --- Saving --------------------------------------------------------------------

func to_dict() -> Dictionary:
	var st: Array = []
	for b: int in stain:
		st.append(b)
	return {
		"mode": mode, "level_id": level_id, "field": field.to_dict(), "tray": tray.duplicate(),
		"rng": rng.state, "score": score, "placed": placed, "captures": captures, "biggest": biggest,
		"gems_captured": gems_captured, "combos": combos, "best_turn": best_turn, "refills": refills,
		"continues": continues, "hints": hints, "tutorial": tutorial, "end": int(end),
		"sequence": sequence.duplicate(), "seq_pos": seq_pos, "goal": goal.duplicate(), "par": par.duplicate(),
		"thresholds": thresholds.duplicate(), "hop": hop, "next_rock_at": next_rock_at,
		"stain": st, "pens_total": pens_total,
	}


static func from_dict(d: Dictionary) -> RunState:
	var s: RunState = RunState.new()
	s.mode = str(d.get("mode", "classic"))
	s.level_id = str(d.get("level_id", ""))
	s.field = Field.from_dict(d.get("field", {}))
	var t: Array = d.get("tray", [])
	for k: int in SLOTS:
		var p: String = str(t[k]) if k < t.size() else ""
		s.tray[k] = p if Pieces.has(p) else ""
	s.rng = Rng.new(int(d.get("rng", 1)))
	for key: String in ["score", "placed", "captures", "biggest", "gems_captured", "combos", "best_turn", "refills", "continues", "hints", "seq_pos", "pens_total"]:
		s.set(key, int(d.get(key, 0)))
	s.next_rock_at = int(d.get("next_rock_at", FIRST_ROCK_AT))
	s.tutorial = bool(d.get("tutorial", false))
	s.end = clampi(int(d.get("end", 0)), 0, End.size() - 1) as End
	for p: Variant in d.get("sequence", []):
		s.sequence.append(str(p))
	s.goal = d.get("goal", {})
	s.par = d.get("par", [])
	s.thresholds = d.get("thresholds", [])
	s.hop = bool(d.get("hop", false))
	var st: Array = d.get("stain", [])
	for i: int in mini(st.size(), s.stain.size()):
		s.stain[i] = clampi(int(st[i]), 0, PEN_COLORS)
	return s
